# Nate Hopkins vs. the Underworld

A 2D side-scrolling brawler/platformer built in **Godot 4.7 (GDScript)**. Fight your way through five levels of the Underworld, punch out a rogues' gallery of tormented souls, defeat two boss "exes," and prove your worth in a final rhythm-game showdown — all wrapped in a self-aware, comedic dating-sim story.

## Story

Nate Hopkins has a track record of breaking hearts. At a party, he meets Hazel — and immediately gets dragged into the Underworld by Aphrodite herself, who isn't about to let history repeat itself. To earn his way back to the world of the living (and a shot with Hazel), Nate has to fight through five levels of hell, defeat the ghosts of his past relationships, and finally prove he can keep a beat.

## Gameplay

- **Movement & combat:** Run, jump, block, and chain a 4-hit ground combo (punch → kick → punch → uppercut), plus a heavy attack, an aerial slam, and a cooldown-gated special move.
- **Enemies:** Four enemy types with distinct behavior — a basic chaser, a fast dodging imp, a shield-blocking knight, and a ranged shooter that lobs projectiles.
- **Bosses:** A multi-phase boss fight with a full attack-state machine (melee, ground slam, charge, ranged spit, teleport, and a projectile "rain" attack), with an enrage phase that kicks in at low health.
- **Rhythm finale:** After both bosses fall, prove yourself in a Guitar-Hero-style rhythm minigame — hit the right key (J / K / L) on the beat, with combo tracking and a miss-streak fail state.
- **Progression:** Earn coins and XP from defeated enemies, level up to increase max HP, and unlock hints scattered through the levels.

## Controls

| Action | Keys |
|---|---|
| Move | `A` / `D` or Arrow Keys |
| Jump | `W` / `Up` / `Space` |
| Attack (combo) | `J` / `Z` |
| Heavy Attack | `K` / `X` |
| Special | `L` / `C` |
| Block | `Q` |
| Pause | `Esc` |

Controls are registered programmatically at startup (see `autoload/input_setup.gd`), so they're guaranteed to be consistent even if the project's Input Map is reset.

## Tech Stack

- **Engine:** [Godot 4.7](https://godotengine.org/)
- **Language:** GDScript
- **Architecture:**
  - `autoload/` — global singletons: `GameState` (persistent run data: HP, money, XP, level, dialogue/rhythm config) and `InputSetup` (keybinding registration).
  - `scenes/player/` — player movement, combat, and damage/death handling.
  - `scenes/enemies/` — enemy AI and combat behavior.
  - `scenes/bosses/` — boss fight state machine, boss arena, boss projectiles, and the rhythm-game finale.
  - `scenes/items/` — pickups and environmental hazards (coins, lava, spikes, falling rocks).
  - `scenes/levels/` — level scenes, moving platforms, doors, and hint zones.
  - `scenes/ui/` — main menu, HUD, pause menu, and death screen.
  - `scenes/dialogue/` — a lightweight line-by-line dialogue/cutscene system.

## Running the Project

1. Install [Godot 4.7](https://godotengine.org/download) or later.
2. Clone the repository:
   ```bash
   git clone https://github.com/nasiftahmid-ux/Nate_Hopkins_vs._the_underworld.git
   ```
3. Open Godot, choose **Import**, and select the `project.godot` file in the cloned folder.
4. Press **Play** (or `F5`) to run the game.

There's also a level-select screen on the title menu for jumping straight into any level, either boss fight, or either phase of the rhythm finale for testing purposes.

## Project Status

This is an actively developed solo project. Current focus areas include reducing duplicated logic between enemy and level scripts and adding persistent save/load support for player progress between sessions.

## License

No license has been specified yet — all rights reserved by default. If you'd like to use or build on this project, please reach out first.
