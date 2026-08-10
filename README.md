# Zombie Town Godot

Godot migration of Zombie Town. The existing browser version remains a separate playable/reference build.

## Prototype 0.1 goal

The first milestone is a small playable vertical slice focused on feel rather than final art:

- First-person movement
- Mouse and controller look
- Sprint, crouch, and jump
- M1911-style pistol shooting and reload
- Basic recoil and ammo tracking
- One zombie archetype
- Zombie chase and melee damage
- Points, kills, and headshots
- Round spawning
- Minimal HUD

The prototype intentionally uses graybox geometry and primitive models. Once movement, shooting, and zombie combat feel right, we will begin importing Town and the production character/weapon assets.

## Running it

1. Clone this repository.
2. Open `project.godot` in Godot 4.x.
3. Press **F6/F5** or click **Run Project**.
4. Click the game window to capture the mouse.
5. Press `Esc` to release the mouse.

### Controls

- `WASD`: Move
- `Shift`: Sprint
- `Ctrl` or `C`: Crouch
- `Space`: Jump
- Mouse: Look
- Left click: Fire
- Right click: Aim down sights
- `R`: Reload
- Gamepad: Left stick move, right stick look, RT fire, LT ADS, A jump, B crouch, left stick click sprint, X reload

## Migration rule

The browser build stays alive. This repository is the higher-ceiling Godot version and uses the web game as its gameplay/reference specification while systems are migrated one at a time.
