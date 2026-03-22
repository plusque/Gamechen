# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Centipede arcade game clone built in **Godot 4.6** with GDScript. German UI text. All game logic lives in a single file (`godot/main.gd`, ~1200 lines). No external dependencies or asset files — audio is procedurally synthesized, graphics use Godot's `_draw()` API.

## Running the Game

```bash
# Open in Godot editor, then press F5
# Or via CLI:
godot --path godot/
```

## Architecture

**Single-file monolith** (`godot/main.gd`) containing:

- **Inner classes**: `Segment`, `BlockData`, `Bullet`, `PowerUp`, `Particle` — data containers for game entities
- **Game state machine**: `MENU → PLAYING → LEVEL_COMPLETE → GAME_OVER`
- **Grid system**: 30x32 cells, 20px each. Blocks stored in `Dictionary` keyed by `"col,row"` string for O(1) lookup
- **Rendering**: Everything drawn in `_draw()` override — no sprites or scene tree nodes for game objects
- **Audio**: 6 procedural sounds generated as `AudioStreamWAV` from sine waves in `_ready()`
- **Persistence**: Highscores saved to `user://highscores.json`

**Key game loops:**
- `_process(delta)` — player input, bullet movement, power-up timers, collision detection, win/lose checks
- `_tick_centipedes()` — called on timer interval, moves centipede chains one grid step. Detects bottom-escape and spawns reinforcements
- `_draw()` — full frame redraw every frame (background, blocks, centipedes, player, bullets, particles, overlays)

**Centipede mechanics:**
- Array of chains, each chain = Array of `Segment`. Head moves, body follows previous positions
- Hit splits chain into two independent chains; segment becomes a block
- Segments can be `shielded` (absorbs one extra hit, blue ring visual)
- 4 color palettes (`WORM_PALETTES`) assigned by `color_id` on each segment
- Chains escaping bottom respawn from top with a smaller "friend" chain (wave system)

**Power-up system:**
- 5 types: double, triple, rapid, shield, piercing — each with timer (8s default)
- Drop from destroyed segments (30% chance), fall with gravity, collectible by touch or shooting
- Affect bullet firing pattern in `_fire_bullets()`

## GDScript Style

- Godot 4 requires explicit type annotations when `:=` inference fails on mixed int/float expressions. Use `var x: float = ...` instead of `var x := ...` in those cases
- Inner classes cannot be typed as return values in some contexts — use untyped `Array` and cast on access
- All constants use `UPPER_SNAKE_CASE` with `:=` inference
- German text uses ASCII-safe characters (ae/oe/ue instead of umlauts)
