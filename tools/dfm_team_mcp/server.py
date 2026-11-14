from __future__ import annotations

import os
import sqlite3
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("dfm-team-hub")

PROTECTED = {
    ".git", ".godot", ".env", ".venv", "__pycache__", "node_modules",
    ".import", ".idea", ".vscode"
}
TEXT_EXTENSIONS = {
    ".md", ".txt", ".json", ".yaml", ".yml", ".toml", ".cfg",
    ".gd", ".tscn", ".tres", ".gdshader", ".csv", ".xml"
}

def project_root() -> Path:
    raw = os.getenv("DFM_PROJECT_ROOT")
    if not raw:
        raise RuntimeError("Set DFM_PROJECT_ROOT to the local Godot project directory.")
    root = Path(raw).expanduser().resolve()
    if not root.is_dir() or not (root / "project.godot").is_file():
        raise RuntimeError(f"Not a Godot project directory: {root}")
    return root

def safe_project_path(relative_path: str) -> Path:
    root = project_root()
    candidate = (root / relative_path).resolve()
    if candidate != root and root not in candidate.parents:
        raise ValueError("Path escapes DFM_PROJECT_ROOT.")
    rel = candidate.relative_to(root)
    if any(part in PROTECTED or part.startswith(".env") for part in rel.parts):
        raise ValueError("Protected path.")
    return candidate

def db_path() -> Path:
    base = Path(os.getenv("DFM_TEAM_DATA", str(Path.home() / ".dfm-team"))).expanduser()
    base.mkdir(parents=True, exist_ok=True)
    return base / "team.sqlite3"

def db():
    con = sqlite3.connect(db_path())
    con.row_factory = sqlite3.Row
    con.execute("""CREATE TABLE IF NOT EXISTS tasks (
        task_id TEXT PRIMARY KEY,
        department TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        handoff_to TEXT NOT NULL DEFAULT '',
        result TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )""")
    con.commit()
    return con

def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()

@mcp.tool()
def project_status() -> dict:
    """Return project path, Godot version from project.godot metadata when available, and Git branch/status."""
    root = project_root()
    branch = subprocess.run(
        ["git", "-C", str(root), "branch", "--show-current"],
        capture_output=True, text=True, timeout=10
    )
    status = subprocess.run(
        ["git", "-C", str(root), "status", "--short"],
        capture_output=True, text=True, timeout=10
    )
    project_file = (root / "project.godot").read_text(encoding="utf-8", errors="replace")
    return {
        "project_root": str(root),
        "is_git_repo": branch.returncode == 0,
        "branch": branch.stdout.strip() if branch.returncode == 0 else None,
        "working_tree": status.stdout.strip() if status.returncode == 0 else None,
        "project_name": next((line.split("=", 1)[1].strip().strip('"')
                              for line in project_file.splitlines()
                              if line.startswith("config/name=")), "Unknown")
    }

@mcp.tool()
def list_project_files(subdirectory: str = "", max_items: int = 250) -> list[str]:
    """List project files for inventory. Hidden and protected directories are excluded."""
    root = project_root()
    base = safe_project_path(subdirectory) if subdirectory else root
    if not base.is_dir():
        raise ValueError("Directory does not exist.")
    output = []
    for item in base.rglob("*"):
        rel = item.relative_to(root)
        if any(part in PROTECTED or part.startswith(".") for part in rel.parts):
            continue
        if item.is_file():
            output.append(rel.as_posix())
            if len(output) >= max(1, min(max_items, 500)):
                break
    return output

@mcp.tool()
def read_project_file(relative_path: str, max_chars: int = 30000) -> str:
    """Read a text file inside the project. Binary files and protected paths are rejected."""
    path = safe_project_path(relative_path)
    if not path.is_file():
        raise ValueError("File not found.")
    if path.suffix.lower() not in TEXT_EXTENSIONS:
        raise ValueError("Unsupported or binary file type.")
    if path.stat().st_size > 1_000_000:
        raise ValueError("File exceeds 1 MB; inspect a smaller file.")
    content = path.read_text(encoding="utf-8", errors="replace")
    return content[:max(1000, min(max_chars, 100000))]

@mcp.tool()
def create_new_project_file(relative_path: str, content: str) -> dict:
    """Create a NEW text file only. Never overwrites. Existing game files require separate explicit authorization."""
    path = safe_project_path(relative_path)
    if path.suffix.lower() not in TEXT_EXTENSIONS:
        raise ValueError("Only supported text file extensions can be created.")
    if path.exists():
        raise FileExistsError("File already exists. This tool never overwrites existing files.")
    if len(content.encode("utf-8")) > 500_000:
        raise ValueError("Content exceeds 500 KB.")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    return {"created": True, "path": path.relative_to(project_root()).as_posix()}

@mcp.tool()
def create_team_task(department: str, title: str, description: str,
                     priority: str = "medium", handoff_to: str = "") -> dict:
    """Create a shared task. Departments: direction, engineering, art, narrative, qa."""
    allowed = {"direction", "engineering", "art", "narrative", "qa"}
    if department not in allowed:
        raise ValueError(f"department must be one of {sorted(allowed)}")
    if priority not in {"low", "medium", "high", "critical"}:
        raise ValueError("Invalid priority.")
    task_id = "DFM-" + uuid.uuid4().hex[:8].upper()
    stamp = timestamp()
    with db() as con:
        con.execute("""INSERT INTO tasks
            (task_id, department, title, description, priority, status, handoff_to, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 'backlog', ?, ?, ?)""",
            (task_id, department, title, description, priority, handoff_to, stamp, stamp))
    return {"task_id": task_id, "status": "backlog"}

@mcp.tool()
def list_team_tasks(status: str = "", department: str = "") -> list[dict]:
    """List tasks, optionally filtered by status or department."""
    query = "SELECT * FROM tasks WHERE 1=1"
    args = []
    if status:
        query += " AND status=?"; args.append(status)
    if department:
        query += " AND department=?"; args.append(department)
    query += " ORDER BY created_at DESC"
    with db() as con:
        return [dict(row) for row in con.execute(query, args).fetchall()]

@mcp.tool()
def update_team_task(task_id: str, status: str = "", result: str = "",
                     handoff_to: str = "") -> dict:
    """Update task status/result. Status: backlog, in_progress, blocked, review, done."""
    allowed = {"backlog", "in_progress", "blocked", "review", "done"}
    if status and status not in allowed:
        raise ValueError(f"status must be one of {sorted(allowed)}")
    with db() as con:
        row = con.execute("SELECT * FROM tasks WHERE task_id=?", (task_id,)).fetchone()
        if row is None:
            raise ValueError("Task not found.")
        new_status = status or row["status"]
        new_result = result or row["result"]
        new_handoff = handoff_to or row["handoff_to"]
        con.execute("""UPDATE tasks SET status=?, result=?, handoff_to=?, updated_at=?
                       WHERE task_id=?""",
                    (new_status, new_result, new_handoff, timestamp(), task_id))
    return {"task_id": task_id, "status": new_status, "handoff_to": new_handoff}

if __name__ == "__main__":
    mcp.run(transport="stdio")
