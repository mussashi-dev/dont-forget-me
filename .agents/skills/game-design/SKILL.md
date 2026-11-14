---
name: game-design
description: Game design methodology, documentation, mechanics design, and balancing for Godot 4.x projects.
---

# Game Design Skill

Structured game design methodology for planning, documenting, and balancing game projects.

## Game Design Document (GDD) Template

When asked to create a GDD, follow this structure:

```markdown
# [Game Title] — Game Design Document

## 1. Overview
- **Genre:** (Platformer, Roguelike, RPG, etc.)
- **Platform:** (PC, Web, Mobile)
- **Target Audience:** (Age, experience level)
- **Elevator Pitch:** (1-2 sentences)
- **Unique Selling Point (USP):**

## 2. Core Gameplay Loop
- What does the player DO every 30 seconds?
- What does the player DO every 5 minutes?
- What does the player DO every session?

## 3. Mechanics
- **Primary Mechanics:** (movement, combat, building)
- **Secondary Mechanics:** (inventory, crafting, dialog)
- **Progression Systems:** (leveling, unlocks, upgrades)

## 4. Game World
- **Setting & Theme:**
- **Art Style:**
- **Levels/Areas:**

## 5. Characters
- **Player Character:**
- **NPCs:**
- **Enemies & Bosses:**

## 6. UI/UX Flow
- Screen flow diagram
- HUD elements

## 7. Audio
- Music style
- Key sound effects

## 8. Technical
- Engine: Godot 4.x
- Target resolution
- Performance targets

## 9. Scope & Milestones
- MVP features
- Nice-to-have features
- Timeline
```

## MDA Framework (Mechanics-Dynamics-Aesthetics)

Use MDA to analyze and design systems:

1. **Mechanics** — Rules and systems (jump height, damage formulas, inventory slots)
2. **Dynamics** — Emergent behavior from mechanics (risk/reward, resource management)
3. **Aesthetics** — Emotional responses (challenge, discovery, fellowship, expression)

Design from Aesthetics → Dynamics → Mechanics: decide what the player should *feel*, then what behaviors create that feeling, then what rules produce those behaviors.

## Core Loop Design

```
     ┌──────────────────────┐
     │     CORE ACTION      │  ← What player does most (30-sec loop)
     │  (jump, shoot, move) │
     └──────────┬───────────┘
                │
     ┌──────────▼───────────┐
     │     REWARD/RISK      │  ← Feedback (5-min loop)
     │  (loot, score, death)│
     └──────────┬───────────┘
                │
     ┌──────────▼───────────┐
     │    PROGRESSION       │  ← Long-term motivation (session loop)
     │  (levels, upgrades)  │
     └──────────┬───────────┘
                │
                └──────→ back to CORE ACTION
```

## Difficulty Balancing

- **Linear curve** — Steady increase (puzzle games)
- **Staircase curve** — Plateaus with spikes (Mega Man)
- **Saw-tooth** — Tension/release cycles (Resident Evil)
- **Inverse difficulty** — Harder at start, easier as player gains power (RPGs)

### Balancing checklist:
- Playtest with 3+ people of varying skill
- Track death/failure frequency per section
- Ensure difficulty knobs are `@export` variables, not hardcoded
- Consider dynamic difficulty adjustment (DDA) for accessibility

## Scope Management for Indies

**MVP approach:**
1. List all features
2. Categorize: **Must Have** | **Should Have** | **Nice to Have**
3. Build Must Have first → playtest → iterate
4. Add Should Have only if core is solid
5. Nice to Have = post-launch or sequel

**Time estimates:** Multiply your estimate by 2.5 (Hofstadter's Law).

## Accessibility Guidelines

- Remappable controls (use InputMap in Godot)
- Colorblind modes (avoid red/green only; add symbols)
- Subtitles for dialog and important audio cues
- Adjustable game speed / difficulty
- Screen reader support for menus
- Large, readable fonts (min 24px at 1080p)
- Controller + keyboard + mouse support
- Visual alternatives for audio cues
