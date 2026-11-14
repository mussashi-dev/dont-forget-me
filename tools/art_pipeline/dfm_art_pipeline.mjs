#!/usr/bin/env node
/**
 * DFM Art Pipeline CLI & Inbox Watcher (Zero-Cost Asset Flow)
 *
 * Bridges DFM Team MCP (SQLite tasks), visual references, manual/Antigravity/pxl
 * image generation, strict PNG RGBA validation, Pixel Art MCP handoff, and
 * explicit-approval Godot asset integration.
 *
 * Uses only Node.js built-in modules (v22+/v24+) and Windows PowerShell System.Drawing
 * for optional chroma-key / nearest-neighbor downscaling. Never calls paid APIs.
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import zlib from "node:zlib";
import { execFileSync } from "node:child_process";
import { DatabaseSync } from "node:sqlite";

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const SUPPORTED_INPUT_EXTS = new Set([".png", ".jpg", ".jpeg", ".webp", ".bmp"]);
const VALID_DEPARTMENTS = new Set(["direction", "engineering", "art", "narrative", "qa"]);
const VALID_PRIORITIES = new Set(["low", "medium", "high", "critical"]);

function parseArgs(argv) {
  const args = argv.slice(2);
  const command = args.length > 0 && !args[0].startsWith("-") ? args.shift() : "help";
  const opts = {};
  const positionals = [];

  for (let i = 0; i < args.length; i++) {
    const token = args[i];
    if (!token.startsWith("--")) {
      positionals.push(token);
      continue;
    }
    const rawKey = token.slice(2);
    if (rawKey.includes("=")) {
      const idx = rawKey.indexOf("=");
      opts[rawKey.slice(0, idx)] = rawKey.slice(idx + 1);
      continue;
    }
    const next = args[i + 1];
    if (next === undefined || next.startsWith("--")) {
      opts[rawKey] = true;
    } else {
      opts[rawKey] = next;
      i++;
    }
  }
  return { command, opts, positionals };
}

function getProjectRoot() {
  const envRoot = process.env.DFM_PROJECT_ROOT;
  if (envRoot && fs.existsSync(path.join(envRoot, "project.godot"))) {
    return path.resolve(envRoot);
  }
  let dir = path.resolve(process.cwd());
  for (let i = 0; i < 6; i++) {
    if (fs.existsSync(path.join(dir, "project.godot"))) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error("Could not locate project.godot. Run from repo root or set DFM_PROJECT_ROOT.");
}

function getPaths(root) {
  const generatedDir = path.join(root, "assets", "_generated");
  return {
    root,
    generatedDir,
    briefsDir: path.join(generatedDir, "briefs"),
    promptsDir: path.join(generatedDir, "prompts"),
    inboxDir: path.join(generatedDir, "inbox"),
    validatedDir: path.join(generatedDir, "validated"),
    rejectedDir: path.join(generatedDir, "rejected"),
    referenceDir: path.join(root, "assets", "_reference"),
    imageProcessorPs1: path.join(root, "tools", "art_pipeline", "image_processor.ps1"),
  };
}

function ensurePipelineDirs(paths) {
  for (const dir of [
    paths.generatedDir,
    paths.briefsDir,
    paths.promptsDir,
    paths.inboxDir,
    paths.validatedDir,
    paths.rejectedDir,
  ]) {
    fs.mkdirSync(dir, { recursive: true });
  }
  const gdignorePath = path.join(paths.generatedDir, ".gdignore");
  if (!fs.existsSync(gdignorePath)) {
    fs.writeFileSync(gdignorePath, "", "utf8");
  }
}

function getDfmDbPath() {
  const base = process.env.DFM_TEAM_DATA || path.join(os.homedir(), ".dfm-team");
  fs.mkdirSync(base, { recursive: true });
  return path.join(base, "team.sqlite3");
}

function openDfmDb() {
  const dbPath = getDfmDbPath();
  const db = new DatabaseSync(dbPath);
  db.exec(`CREATE TABLE IF NOT EXISTS tasks (
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
  )`);
  return { db, dbPath };
}

function utcIsoNow() {
  return new Date().toISOString();
}

function slugify(value) {
  return String(value || "asset")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "") || "asset";
}

function toPosixRel(root, absPath) {
  return path.relative(root, absPath).split(path.sep).join("/");
}

function collectVisualReferences(paths) {
  const refImages = [];
  if (fs.existsSync(paths.referenceDir)) {
    const walk = (dir) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          walk(full);
        } else if (/\.(png|jpe?g|webp|txt)$/i.test(entry.name)) {
          refImages.push(toPosixRel(paths.root, full));
        }
      }
    };
    walk(paths.referenceDir);
    refImages.sort();
  }

  const spritesDocPath = path.join(paths.root, "documentation", "sprites_topdown.md");
  const docSummary = fs.existsSync(spritesDocPath)
    ? fs.readFileSync(spritesDocPath, "utf8")
        .split(/\r?\n/)
        .filter((line) => line.startsWith("- ") || line.startsWith("## "))
        .slice(0, 12)
    : [];

  const esquecidoGenPath = path.join(paths.root, "tools", "gen_esquecido_prototype_assets.ps1");
  const paletteHexes = new Set();
  if (fs.existsSync(esquecidoGenPath)) {
    const text = fs.readFileSync(esquecidoGenPath, "utf8");
    for (const match of text.matchAll(/#[0-9a-fA-F]{6}\b/g)) {
      paletteHexes.add(match[0].toLowerCase());
    }
  }

  return {
    reference_files: refImages,
    conventions_source: fs.existsSync(spritesDocPath) ? "documentation/sprites_topdown.md" : null,
    conventions_highlights: docSummary,
    esquecido_palette: Array.from(paletteHexes).slice(0, 24),
    godot_render_rules: {
      viewport: "640x360",
      scale_meter_px: "18-19 px",
      texture_filter: "Nearest (default_texture_filter=0)",
      shadow_rule: "Never bake floor shadow into sprite; Godot uses separate Polygon2D shadow nodes",
      alpha_rule: "Hard pixel-art transparency (Alpha 0 or 255)",
    },
  };
}

function findMatchingBrief(paths, { taskId, assetName }) {
  if (!fs.existsSync(paths.briefsDir)) return null;
  const files = fs.readdirSync(paths.briefsDir).filter((f) => f.endsWith(".json"));
  for (const file of files) {
    const full = path.join(paths.briefsDir, file);
    try {
      const data = JSON.parse(fs.readFileSync(full, "utf8"));
      if (taskId && data.task_id === taskId) return { path: full, data };
      if (assetName && data.asset_name === assetName) return { path: full, data };
    } catch {
      // ignore malformed JSON
    }
  }
  return null;
}

function buildPromptMarkdown(brief, paths) {
  const refList = brief.references.reference_files.length > 0
    ? brief.references.reference_files.map((r) => `- \`${r}\``).join("\n")
    : "- *(nenhum arquivo encontrado em assets/_reference/)*";

  const paletteStr = brief.references.esquecido_palette.length > 0
    ? brief.references.esquecido_palette.slice(0, 12).join(", ")
    : "#120b1c, #2b1b45, #6b5896, #8f3a8a, #ffcf70";

  const positivePrompt = [
    `Top-down 2D pixel art game sprite for the indie game DON'T FORGET ME: ${brief.description}.`,
    `Exact target sprite grid ${brief.width}x${brief.height} pixels (16-bit cozy-melancholic dark fantasy pixel art, crisp 1px dark outline #120b1c, hue-shifted shading).`,
    `Style aligned with Pablita and Pipop sheets (soft handmade toy/memory aesthetic, muted lilacs/purples/warm brass accents from palette ${paletteStr}).`,
    `Centered single asset on a pure solid flat magenta (#FF00FF) background with NO floor cast shadow, NO anti-aliasing, NO text, NO borders.`,
  ].join(" ");

  const negativePrompt = [
    "blurry, anti-aliased edges, soft gradients, drop shadow on floor, ground shadow, multiple sprites,",
    "sprite sheet grid labels, text, watermark, UI frame, 3D render, realistic photo, high-frequency noise.",
  ].join(" ");

  const inboxExpected = `assets/_generated/inbox/${brief.asset_name}.png`;

  return `# Prompt de Geração — ${brief.title}

- **Task ID (DFM Team MCP):** \`${brief.task_id}\`
- **Asset Name:** \`${brief.asset_name}\`
- **Categoria:** \`${brief.category}\`
- **Dimensões Alvo:** \`${brief.width}x${brief.height}\` px (PNG 32-bit RGBA, transparência rígida)
- **Alinhamento no Quadro:** \`${brief.align}\`
- **Destino Godot (após aprovação):** \`${brief.target_path}\`

## Referências Visuais Consultadas
${refList}
- **Convenções:** \`documentation/sprites_topdown.md\` (escala \`1m ≈ 18–19 px\`, filtro \`Nearest\`, sem sombra acoplada ao sprite)

## Prompt Positivo (Copiar para Gemini Web / Google AI Pro / Antigravity \`image-generator\` / ChatGPT Free)
\`\`\`text
${positivePrompt}
\`\`\`

## Prompt Negativo / Restrições
\`\`\`text
${negativePrompt}
\`\`\`

## Alternativa 100% Gratuita e Determinística (\`pxl-pixel-art\`)
Caso prefira gerar diretamente na grade exata \`${brief.width}x${brief.height}\` sem pós-processamento:
1. Crie \`tools/pxl/${brief.asset_name}.px.js\` usando a skill \`pxl-pixel-art\`.
2. Execute: \`node "C:\\Users\\dann1\\.gemini\\config\\skills\\pxl-pixel-art\\bin\\pxl.js" build tools/pxl/${brief.asset_name}.px.js --out tools/pxl/out/${brief.asset_name}\`
3. Copie o PNG gerado para \`${inboxExpected}\`.

## Recebimento e Validação Automática
- Salve a imagem gerada (PNG transparente ou JPEG com fundo \`#FF00FF\`) em:
  \`${inboxExpected}\` (ou \`.jpg\` com \`--auto-convert\`).
- Execute a validação:
  \`node tools/art_pipeline/dfm_art_pipeline.mjs intake --file ${inboxExpected} --task-id ${brief.task_id}\`
- Se vier do Gemini Web / \`image-generator\` em alta resolução com fundo \`#FF00FF\`:
  \`node tools/art_pipeline/dfm_art_pipeline.mjs intake --file <caminho_da_imagem> --asset-name ${brief.asset_name} --task-id ${brief.task_id} --auto-convert\`
`;
}

function cmdBrief(opts, paths) {
  const { db, dbPath } = openDfmDb();
  try {
    let taskRow = null;
    if (opts["task-id"]) {
      taskRow = db.prepare("SELECT * FROM tasks WHERE task_id = ?").get(String(opts["task-id"]));
    } else if (opts["pull-next"]) {
      taskRow = db.prepare(
        "SELECT * FROM tasks WHERE department = 'art' AND status IN ('backlog', 'in_progress') ORDER BY created_at ASC LIMIT 1"
      ).get();
    }

    const title = String(opts.title || taskRow?.title || "Untitled Art Asset");
    const description = String(opts.description || taskRow?.description || title);
    const assetName = slugify(opts["asset-name"] || title);
    const category = slugify(opts.category || "objects");
    const width = Number.parseInt(opts.width || "32", 10);
    const height = Number.parseInt(opts.height || "32", 10);
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      throw new Error("Invalid --width or --height; expected positive integers.");
    }

    const align = opts.align === "bottom" ? "bottom" : "center";
    const targetPath = String(opts["target-path"] || `assets/${category}/${assetName}.png`).replace(/\\/g, "/");
    const priority = VALID_PRIORITIES.has(opts.priority) ? opts.priority : (taskRow?.priority || "medium");
    const department = VALID_DEPARTMENTS.has(opts.department) ? opts.department : "art";

    let taskId = taskRow?.task_id;
    const now = utcIsoNow();
    if (!taskId) {
      taskId = "DFM-" + crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase();
      db.prepare(`INSERT INTO tasks
        (task_id, department, title, description, priority, status, handoff_to, result, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 'in_progress', 'art-generation', '', ?, ?)`
      ).run(taskId, department, title, description, priority, now, now);
    } else {
      db.prepare("UPDATE tasks SET status = 'in_progress', handoff_to = 'art-generation', updated_at = ? WHERE task_id = ?")
        .run(now, taskId);
    }

    const references = collectVisualReferences(paths);
    const brief = {
      task_id: taskId,
      department,
      title,
      description,
      asset_name: assetName,
      category,
      width,
      height,
      align,
      target_path: targetPath,
      require_transparency: opts["no-transparency"] ? false : true,
      require_hard_alpha: opts["allow-semitransparent"] ? false : true,
      references,
      created_at: now,
      db_path: dbPath,
    };

    const briefJsonPath = path.join(paths.briefsDir, `${taskId}.json`);
    const promptMdPath = path.join(paths.promptsDir, `${taskId}_prompt.md`);
    fs.writeFileSync(briefJsonPath, JSON.stringify(brief, null, 2) + "\n", "utf8");
    fs.writeFileSync(promptMdPath, buildPromptMarkdown(brief, paths), "utf8");

    const briefRel = toPosixRel(paths.root, briefJsonPath);
    const promptRel = toPosixRel(paths.root, promptMdPath);
    db.prepare("UPDATE tasks SET result = ?, updated_at = ? WHERE task_id = ?")
      .run(`Brief: ${briefRel} | Prompt: ${promptRel}`, utcIsoNow(), taskId);

    console.log(JSON.stringify({
      ok: true,
      task_id: taskId,
      asset_name: assetName,
      dimensions: `${width}x${height}`,
      brief_path: briefRel,
      prompt_path: promptRel,
      references_found: references.reference_files.length,
      dfm_db: dbPath,
    }, null, 2));
  } finally {
    db.close();
  }
}

function paethPredictor(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function detectNonPngSignature(buf) {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return "JPEG";
  if (buf.length >= 12 && buf.subarray(0, 4).toString("ascii") === "RIFF" && buf.subarray(8, 12).toString("ascii") === "WEBP") return "WEBP";
  if (buf.length >= 2 && buf.subarray(0, 2).toString("ascii") === "BM") return "BMP";
  if (buf.length >= 6 && buf.subarray(0, 4).toString("ascii") === "GIF8") return "GIF";
  return "UNKNOWN";
}

/**
 * Pure Node.js PNG binary parser & pixel-level RGBA analyzer.
 * Validates PNG magic header, IHDR metadata, non-interlaced IDAT pixel stream,
 * transparency counts, semi-transparent halo counts, and unique visible color count.
 */
function inspectPng(filePath) {
  const buf = fs.readFileSync(filePath);
  if (buf.length < 24 || !buf.subarray(0, 8).equals(PNG_SIGNATURE)) {
    return {
      validFormat: false,
      detectedFormat: detectNonPngSignature(buf),
      fileBytes: buf.length,
      error: `Invalid PNG binary signature (detected ${detectNonPngSignature(buf)}).`,
    };
  }

  let offset = 8;
  let ihdr = null;
  let plte = null;
  let trns = null;
  const idatChunks = [];

  while (offset + 12 <= buf.length) {
    const length = buf.readUInt32BE(offset);
    const type = buf.subarray(offset + 4, offset + 8).toString("ascii");
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (dataEnd + 4 > buf.length) {
      return { validFormat: false, detectedFormat: "CORRUPT_PNG", fileBytes: buf.length, error: `Truncated PNG chunk ${type}.` };
    }
    const chunkData = buf.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      if (length !== 13) {
        return { validFormat: false, detectedFormat: "CORRUPT_PNG", fileBytes: buf.length, error: "Invalid IHDR length." };
      }
      ihdr = {
        width: chunkData.readUInt32BE(0),
        height: chunkData.readUInt32BE(4),
        bitDepth: chunkData[8],
        colorType: chunkData[9],
        compression: chunkData[10],
        filter: chunkData[11],
        interlace: chunkData[12],
      };
    } else if (type === "PLTE") {
      plte = chunkData;
    } else if (type === "tRNS") {
      trns = chunkData;
    } else if (type === "IDAT") {
      idatChunks.push(chunkData);
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4;
  }

  if (!ihdr || idatChunks.length === 0) {
    return { validFormat: false, detectedFormat: "CORRUPT_PNG", fileBytes: buf.length, error: "Missing IHDR or IDAT chunk." };
  }
  if (ihdr.interlace !== 0) {
    return { validFormat: false, detectedFormat: "PNG_INTERLACED", fileBytes: buf.length, error: "Interlaced PNGs are not supported; export non-interlaced PNG." };
  }
  if (ihdr.bitDepth !== 8) {
    return {
      validFormat: false,
      detectedFormat: "PNG",
      ...ihdr,
      fileBytes: buf.length,
      error: `Expected 8-bit per channel PNG (got bitDepth=${ihdr.bitDepth}).`,
    };
  }

  const channelsByType = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };
  const channels = channelsByType[ihdr.colorType];
  if (!channels) {
    return { validFormat: false, detectedFormat: "PNG", ...ihdr, fileBytes: buf.length, error: `Unsupported PNG colorType=${ihdr.colorType}.` };
  }

  const rawStream = zlib.inflateSync(Buffer.concat(idatChunks));
  const stride = ihdr.width * channels;
  const expectedLen = (stride + 1) * ihdr.height;
  if (rawStream.length < expectedLen) {
    return { validFormat: false, detectedFormat: "CORRUPT_PNG", ...ihdr, fileBytes: buf.length, error: "Inflated IDAT data is shorter than expected scanlines." };
  }

  const decoded = Buffer.alloc(ihdr.height * stride);
  const bpp = channels;

  for (let y = 0; y < ihdr.height; y++) {
    const rowIn = y * (stride + 1);
    const filterType = rawStream[rowIn];
    const rowOut = y * stride;
    for (let x = 0; x < stride; x++) {
      const rawByte = rawStream[rowIn + 1 + x];
      const a = x >= bpp ? decoded[rowOut + x - bpp] : 0;
      const b = y > 0 ? decoded[(y - 1) * stride + x] : 0;
      const c = (x >= bpp && y > 0) ? decoded[(y - 1) * stride + x - bpp] : 0;
      let val = rawByte;
      if (filterType === 1) val = (rawByte + a) & 0xff;
      else if (filterType === 2) val = (rawByte + b) & 0xff;
      else if (filterType === 3) val = (rawByte + Math.floor((a + b) / 2)) & 0xff;
      else if (filterType === 4) val = (rawByte + paethPredictor(a, b, c)) & 0xff;
      else if (filterType !== 0) {
        return { validFormat: false, detectedFormat: "CORRUPT_PNG", ...ihdr, fileBytes: buf.length, error: `Unknown PNG scanline filter ${filterType}.` };
      }
      decoded[rowOut + x] = val;
    }
  }

  let transparentPixels = 0;
  let opaquePixels = 0;
  let semitransparentPixels = 0;
  const visibleColors = new Set();

  for (let i = 0; i < ihdr.width * ihdr.height; i++) {
    const base = i * channels;
    let r = 0, g = 0, b = 0, a = 255;
    if (ihdr.colorType === 6) {
      r = decoded[base]; g = decoded[base + 1]; b = decoded[base + 2]; a = decoded[base + 3];
    } else if (ihdr.colorType === 2) {
      r = decoded[base]; g = decoded[base + 1]; b = decoded[base + 2];
      if (trns && trns.length >= 6) {
        const tr = trns.readUInt16BE(0) & 0xff;
        const tg = trns.readUInt16BE(2) & 0xff;
        const tb = trns.readUInt16BE(4) & 0xff;
        if (r === tr && g === tg && b === tb) a = 0;
      }
    } else if (ihdr.colorType === 4) {
      r = g = b = decoded[base]; a = decoded[base + 1];
    } else if (ihdr.colorType === 0) {
      r = g = b = decoded[base];
      if (trns && trns.length >= 2 && r === (trns.readUInt16BE(0) & 0xff)) a = 0;
    } else if (ihdr.colorType === 3) {
      const idx = decoded[base];
      if (plte && idx * 3 + 2 < plte.length) {
        r = plte[idx * 3]; g = plte[idx * 3 + 1]; b = plte[idx * 3 + 2];
      }
      if (trns && idx < trns.length) a = trns[idx];
    }

    if (a === 0) transparentPixels++;
    else if (a === 255) {
      opaquePixels++;
      visibleColors.add((r << 16) | (g << 8) | b);
    } else {
      semitransparentPixels++;
      visibleColors.add((r << 16) | (g << 8) | b);
    }
  }

  return {
    validFormat: true,
    detectedFormat: "PNG",
    width: ihdr.width,
    height: ihdr.height,
    bitDepth: ihdr.bitDepth,
    colorType: ihdr.colorType,
    hasAlphaChannel: ihdr.colorType === 4 || ihdr.colorType === 6 || trns !== null,
    transparentPixels,
    opaquePixels,
    semitransparentPixels,
    uniqueColors: visibleColors.size,
    fileBytes: buf.length,
    dataUrl: "data:image/png;base64," + buf.toString("base64"),
  };
}

function runImageProcessor(paths, inputPath, outputPath, { width, height, bgMode, align, quantize }) {
  const psArgs = [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", paths.imageProcessorPs1,
    "-InputPath", inputPath,
    "-OutputPath", outputPath,
    "-TargetWidth", String(width),
    "-TargetHeight", String(height),
    "-BgMode", bgMode,
    "-Align", align,
    "-QuantizeStep", String(quantize),
  ];
  execFileSync("powershell", psArgs, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function validateAgainstSpec(info, spec) {
  const errors = [];
  if (!info.validFormat) {
    errors.push(info.error || `Expected valid PNG file, got ${info.detectedFormat}.`);
    return errors;
  }
  if (spec.width && info.width !== spec.width) {
    errors.push(`Width mismatch: expected ${spec.width}px, got ${info.width}px.`);
  }
  if (spec.height && info.height !== spec.height) {
    errors.push(`Height mismatch: expected ${spec.height}px, got ${info.height}px.`);
  }
  if (spec.requireTransparency) {
    if (!info.hasAlphaChannel) {
      errors.push("PNG has no alpha channel (expected RGBA colorType 6 or tRNS transparency).");
    } else if (info.transparentPixels === 0) {
      errors.push("PNG has 0 transparent pixels (solid background was not removed).");
    }
  }
  if (info.opaquePixels === 0 && info.semitransparentPixels === 0) {
    errors.push("PNG contains no visible foreground pixels (100% transparent).");
  }
  if (spec.requireHardAlpha && info.semitransparentPixels > 0) {
    errors.push(`Detected ${info.semitransparentPixels} semi-transparent anti-aliased pixels (pixel art requires Alpha 0 or 255).`);
  }
  return errors;
}

function processSingleFile(inputFile, opts, paths) {
  if (!fs.existsSync(inputFile)) {
    throw new Error(`Input file not found: ${inputFile}`);
  }
  const parsed = path.parse(inputFile);
  const assetName = slugify(opts["asset-name"] || parsed.name);
  const match = findMatchingBrief(paths, { taskId: opts["task-id"], assetName });
  const brief = match?.data || null;

  const targetWidth = Number.parseInt(opts.width || brief?.width || "32", 10);
  const targetHeight = Number.parseInt(opts.height || brief?.height || "32", 10);
  const align = opts.align || brief?.align || "center";
  const bgMode = opts["bg-mode"] || "auto";
  const quantize = Number.parseInt(opts.quantize || "8", 10);
  const requireTransparency = opts["no-transparency"] ? false : (brief?.require_transparency ?? true);
  const requireHardAlpha = opts["allow-semitransparent"] ? false : (brief?.require_hard_alpha ?? true);

  let fileToInspect = inputFile;
  let convertedFrom = null;

  if (opts["auto-convert"]) {
    const convertedPath = path.join(paths.inboxDir, `${assetName}.png`);
    runImageProcessor(paths, inputFile, convertedPath, {
      width: targetWidth,
      height: targetHeight,
      bgMode,
      align,
      quantize,
    });
    convertedFrom = toPosixRel(paths.root, path.resolve(inputFile));
    fileToInspect = convertedPath;
  }

  const info = inspectPng(fileToInspect);
  const errors = validateAgainstSpec(info, {
    width: targetWidth,
    height: targetHeight,
    requireTransparency,
    requireHardAlpha,
  });

  const isInsideGeneratedDrop =
    path.dirname(path.resolve(fileToInspect)) === path.resolve(paths.inboxDir) ||
    path.dirname(path.resolve(fileToInspect)) === path.resolve(paths.generatedDir);

  const now = utcIsoNow();
  if (errors.length > 0) {
    const ext = path.extname(fileToInspect).toLowerCase() || ".bin";
    const rejectedAssetPath = path.join(paths.rejectedDir, `${assetName}${ext}`);
    const rejectedErrorPath = path.join(paths.rejectedDir, `${assetName}.error.json`);
    if (isInsideGeneratedDrop && fs.existsSync(fileToInspect)) {
      fs.renameSync(fileToInspect, rejectedAssetPath);
    } else {
      fs.copyFileSync(fileToInspect, rejectedAssetPath);
    }
    const errorPayload = {
      passed: false,
      asset_name: assetName,
      task_id: brief?.task_id || opts["task-id"] || null,
      source_file: path.resolve(inputFile),
      converted_from: convertedFrom,
      rejected_at: now,
      errors,
      inspection: { ...info, dataUrl: undefined },
    };
    fs.writeFileSync(rejectedErrorPath, JSON.stringify(errorPayload, null, 2) + "\n", "utf8");
    return {
      passed: false,
      asset_name: assetName,
      rejected_file: toPosixRel(paths.root, rejectedAssetPath),
      error_report: toPosixRel(paths.root, rejectedErrorPath),
      errors,
    };
  }

  const validatedPngPath = path.join(paths.validatedDir, `${assetName}.png`);
  const reportPath = path.join(paths.validatedDir, `${assetName}.report.json`);
  if (isInsideGeneratedDrop && fs.existsSync(fileToInspect)) {
    fs.renameSync(fileToInspect, validatedPngPath);
  } else {
    fs.copyFileSync(fileToInspect, validatedPngPath);
  }

  const report = {
    passed: true,
    asset_name: assetName,
    task_id: brief?.task_id || opts["task-id"] || null,
    brief_path: match ? toPosixRel(paths.root, match.path) : null,
    validated_path: toPosixRel(paths.root, validatedPngPath),
    target_path: brief?.target_path || `assets/${slugify(opts.category || "objects")}/${assetName}.png`,
    converted_from: convertedFrom,
    validated_at: now,
    validation: {
      format: "PNG",
      width: info.width,
      height: info.height,
      bit_depth: info.bitDepth,
      color_type: info.colorType,
      has_alpha_channel: info.hasAlphaChannel,
      transparent_pixels: info.transparentPixels,
      opaque_pixels: info.opaquePixels,
      semitransparent_pixels: info.semitransparentPixels,
      unique_colors: info.uniqueColors,
      file_bytes: info.fileBytes,
    },
    pixel_art_mcp: {
      server: "pixellab",
      tool: "pixelart_workbench",
      status: "pending_review",
      suggested_commands: [
        ["score", info.dataUrl],
        ["lint", info.dataUrl],
        ["inspect", info.dataUrl, "--region", `0,0,${info.width - 1},${info.height - 1}`, "--scale", "10"],
      ],
      data_url: info.dataUrl,
    },
    godot_integration: {
      approved: false,
      integrated: false,
      target_path: brief?.target_path || `assets/${slugify(opts.category || "objects")}/${assetName}.png`,
      required_import_settings: "2D Pixel (Lossless compress/mode=0, Nearest filter, Mipmaps disabled)",
    },
  };
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");

  if (report.task_id) {
    const { db } = openDfmDb();
    try {
      db.prepare("UPDATE tasks SET status = 'review', handoff_to = 'pixellab-mcp', result = ?, updated_at = ? WHERE task_id = ?")
        .run(`Validated PNG: ${report.validated_path} (${info.width}x${info.height}, transparent=${info.transparentPixels}px)`, now, report.task_id);
    } finally {
      db.close();
    }
  }

  return {
    passed: true,
    asset_name: assetName,
    task_id: report.task_id,
    validated_file: report.validated_path,
    report_path: toPosixRel(paths.root, reportPath),
    validation: report.validation,
  };
}

function collectPendingInputs(paths) {
  const candidates = [];
  const scanDir = (dir) => {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!entry.isFile()) continue;
      if (entry.name.startsWith(".")) continue;
      const ext = path.extname(entry.name).toLowerCase();
      if (SUPPORTED_INPUT_EXTS.has(ext)) {
        candidates.push(path.join(dir, entry.name));
      }
    }
  };
  scanDir(paths.inboxDir);
  scanDir(paths.generatedDir);
  return candidates.sort();
}

function cmdIntake(opts, paths) {
  const targets = opts.file ? [path.resolve(opts.file)] : collectPendingInputs(paths);
  if (targets.length === 0) {
    console.log(JSON.stringify({ ok: true, processed: 0, message: "No input files found in assets/_generated/inbox/." }, null, 2));
    return;
  }
  const results = targets.map((file) => processSingleFile(file, opts, paths));
  const anyFailed = results.some((r) => !r.passed);
  console.log(JSON.stringify({ ok: !anyFailed, processed: results.length, results }, null, 2));
  if (anyFailed) process.exitCode = 1;
}

function sleepMs(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function cmdWatch(opts, paths) {
  const intervalMs = Math.max(250, Number.parseInt(opts["interval-ms"] || "1500", 10));
  const maxCycles = opts["max-cycles"] ? Number.parseInt(opts["max-cycles"], 10) : Infinity;
  const seen = new Map();

  console.error(`[dfm-art-watch] Watching ${toPosixRel(paths.root, paths.inboxDir)} (interval=${intervalMs}ms)...`);
  let cycle = 0;
  while (cycle < maxCycles) {
    cycle++;
    const files = collectPendingInputs(paths);
    for (const file of files) {
      const stat = fs.statSync(file);
      const stamp = `${stat.size}:${stat.mtimeMs}`;
      if (seen.get(file) === stamp) continue;
      seen.set(file, stamp);
      try {
        const res = processSingleFile(file, opts, paths);
        console.log(JSON.stringify({ event: "intake", file: toPosixRel(paths.root, file), result: res }));
      } catch (err) {
        console.error(JSON.stringify({ event: "error", file: toPosixRel(paths.root, file), error: err.message }));
      }
    }
    if (cycle < maxCycles) sleepMs(intervalMs);
  }
}

function cmdRecordMcpReview(opts, paths) {
  const assetName = slugify(opts["asset-name"]);
  const reportPath = path.join(paths.validatedDir, `${assetName}.report.json`);
  if (!fs.existsSync(reportPath)) {
    throw new Error(`Validated report not found: ${toPosixRel(paths.root, reportPath)}`);
  }
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const status = String(opts.status || "passed");
  const score = opts.score !== undefined ? Number(opts.score) : null;
  const summary = String(opts.summary || "");
  const now = utcIsoNow();

  report.pixel_art_mcp = {
    ...report.pixel_art_mcp,
    status,
    score,
    summary,
    reviewed_at: now,
  };
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");

  if (report.task_id) {
    const { db } = openDfmDb();
    try {
      const nextHandoff = status === "passed" ? "user-approval" : "art-revision";
      db.prepare("UPDATE tasks SET status = 'review', handoff_to = ?, result = ?, updated_at = ? WHERE task_id = ?")
        .run(nextHandoff, `PixelArt MCP (${status}, score=${score}): ${summary}`, now, report.task_id);
    } finally {
      db.close();
    }
  }

  console.log(JSON.stringify({
    ok: true,
    asset_name: assetName,
    report_path: toPosixRel(paths.root, reportPath),
    mcp_status: status,
    score,
  }, null, 2));
}

function findGodotBinary() {
  const candidates = [
    process.env.GODOT_BIN,
    "C:\\Users\\dann1\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64_console.exe",
  ].filter(Boolean);
  for (const bin of candidates) {
    if (fs.existsSync(bin)) return bin;
  }
  return null;
}

function cmdIntegrate(opts, paths) {
  const assetName = slugify(opts["asset-name"]);
  if (!opts.approve) {
    throw new Error("Refusing to integrate into Godot assets/ without explicit --approve flag.");
  }

  const reportPath = path.join(paths.validatedDir, `${assetName}.report.json`);
  const validatedPng = path.join(paths.validatedDir, `${assetName}.png`);
  if (!fs.existsSync(reportPath) || !fs.existsSync(validatedPng)) {
    throw new Error(`Validated asset/report missing for '${assetName}'. Run intake first.`);
  }

  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  if (!report.passed) {
    throw new Error(`Asset '${assetName}' did not pass validation.`);
  }

  const targetRel = String(opts.target || report.target_path || "").replace(/^res:\/\//, "").replace(/\\/g, "/");
  if (!targetRel.startsWith("assets/") || targetRel.startsWith("assets/_generated/") || targetRel.startsWith("assets/_reference/")) {
    throw new Error(`Unsafe target path '${targetRel}'. Must reside under assets/ (excluding _generated and _reference).`);
  }
  if (!targetRel.endsWith(".png")) {
    throw new Error("Target path must end with .png.");
  }

  const absTarget = path.resolve(paths.root, targetRel);
  if (!absTarget.startsWith(path.resolve(paths.root, "assets") + path.sep)) {
    throw new Error("Target path escapes assets/ directory.");
  }
  if (fs.existsSync(absTarget)) {
    throw new Error(`Target file already exists (${targetRel}). Existing game files are never overwritten automatically.`);
  }

  fs.mkdirSync(path.dirname(absTarget), { recursive: true });
  fs.copyFileSync(validatedPng, absTarget);

  let godotLoadCheck = null;
  if (opts["godot-check"]) {
    const godotBin = findGodotBinary();
    if (godotBin) {
      const resPath = `res://${targetRel}`;
      const expr = `var img = Image.load_from_file('${resPath}'); print('GODOT_IMG_OK ', img.get_width(), 'x', img.get_height(), ' fmt=', img.get_format()); quit(0)`;
      const gdTmp = path.join(os.tmpdir(), `dfm_verify_${Date.now()}.gd`);
      fs.writeFileSync(gdTmp, `extends SceneTree\nfunc _init() -> void:\n\t${expr.replace(/; /g, "\n\t")}\n`, "utf8");
      try {
        const out = execFileSync(godotBin, ["--headless", "--path", paths.root, "-s", gdTmp], {
          encoding: "utf8",
          stdio: ["ignore", "pipe", "pipe"],
        });
        godotLoadCheck = out.trim();
      } finally {
        if (fs.existsSync(gdTmp)) fs.unlinkSync(gdTmp);
      }
    } else {
      godotLoadCheck = "Godot binary not found; skipped headless Image.load_from_file check.";
    }
  }

  const now = utcIsoNow();
  report.godot_integration = {
    approved: true,
    integrated: true,
    target_path: targetRel,
    res_path: `res://${targetRel}`,
    integrated_at: now,
    godot_load_check: godotLoadCheck,
  };
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");

  if (report.task_id) {
    const { db } = openDfmDb();
    try {
      db.prepare("UPDATE tasks SET status = 'done', handoff_to = 'godot-editor', result = ?, updated_at = ? WHERE task_id = ?")
        .run(`Integrated approved PNG at res://${targetRel}`, now, report.task_id);
    } finally {
      db.close();
    }
  }

  console.log(JSON.stringify({
    ok: true,
    asset_name: assetName,
    integrated_path: targetRel,
    res_path: `res://${targetRel}`,
    godot_load_check: godotLoadCheck,
  }, null, 2));
}

function cmdListTasks(opts) {
  const { db, dbPath } = openDfmDb();
  try {
    let sql = "SELECT * FROM tasks WHERE 1=1";
    const params = [];
    if (opts.department) { sql += " AND department = ?"; params.push(opts.department); }
    if (opts.status) { sql += " AND status = ?"; params.push(opts.status); }
    sql += " ORDER BY created_at DESC";
    const rows = db.prepare(sql).all(...params);
    console.log(JSON.stringify({ db_path: dbPath, count: rows.length, tasks: rows }, null, 2));
  } finally {
    db.close();
  }
}

function printHelp() {
  console.log(`DFM Art Pipeline CLI (Zero-Cost Asset Flow)

Commands:
  brief               Create or pull an art task from DFM Team MCP SQLite, inspect
                      assets/_reference/, and generate briefing JSON + prompt Markdown.
    --task-id <id>    Existing DFM-* task ID (optional)
    --pull-next       Pull oldest open 'art' task from DFM Team MCP SQLite
    --title <text>    Asset title
    --asset-name <id> Snake_case filename stem
    --category <dir>  Subdir under assets/ (default: objects)
    --width <px>      Target width (default: 32)
    --height <px>     Target height (default: 32)
    --align <mode>    center | bottom (default: center)
    --target-path <p> Target relative path (e.g. assets/objects/forgotten_key.png)
    --description <t> Visual description for prompt

  intake              Validate PNGs in assets/_generated/inbox/ (or --file) and move
                      passing assets to validated/ or failing ones to rejected/.
    --file <path>     Single image to process (optional)
    --asset-name <id> Override asset name stem
    --task-id <id>    Link explicitly to a DFM-* briefing
    --auto-convert    Convert JPEG/oversized magenta-bg image to target WxH RGBA PNG first
    --bg-mode <m>     auto | magenta | corner | none (default: auto)
    --width <px>      Expected width (overrides brief)
    --height <px>     Expected height (overrides brief)

  watch               Poll assets/_generated/inbox/ for new manual exports.
    --interval-ms <n> Poll interval in ms (default: 1500)
    --max-cycles <n>  Stop after N cycles (useful for automation)
    --auto-convert    Auto-convert dropped JPEGs/oversized images

  record-mcp-review   Record Pixel Art MCP (pixellab:pixelart_workbench) review result.
    --asset-name <id> Validated asset name
    --status <s>      passed | needs_fixes | rejected
    --score <n>       Workbench score (0-100)
    --summary <text>  Lint/review notes

  integrate           Promote an approved PNG from validated/ to assets/ (never overwrites).
    --asset-name <id> Validated asset name
    --target <path>   Relative path under assets/ (optional if in brief)
    --approve         Required explicit user approval flag
    --godot-check     Verify Image.load_from_file() using Godot 4.7.2 headless

  list-tasks          List tasks stored in DFM Team MCP SQLite (~/.dfm-team/team.sqlite3).
`);
}

function main() {
  const { command, opts } = parseArgs(process.argv);
  if (command === "help" || opts.help) {
    printHelp();
    return;
  }

  const root = getProjectRoot();
  const paths = getPaths(root);
  ensurePipelineDirs(paths);

  switch (command) {
    case "brief":
      cmdBrief(opts, paths);
      break;
    case "intake":
      cmdIntake(opts, paths);
      break;
    case "watch":
      cmdWatch(opts, paths);
      break;
    case "record-mcp-review":
      cmdRecordMcpReview(opts, paths);
      break;
    case "integrate":
      cmdIntegrate(opts, paths);
      break;
    case "list-tasks":
      cmdListTasks(opts);
      break;
    default:
      throw new Error(`Unknown command '${command}'. Run with --help for usage.`);
  }
}

try {
  main();
} catch (err) {
  console.error(`ERROR: ${err.message}`);
  process.exit(1);
}
