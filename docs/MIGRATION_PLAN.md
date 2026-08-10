# Zombie Town Godot Migration Plan

The browser version remains supported and acts as the reference build while the Godot version is developed in parallel.

## Prototype 0.1: Core feel

Status: in progress

- [x] Godot project foundation
- [x] Graybox combat arena
- [x] First-person movement
- [x] Mouse look
- [x] Controller movement/look bindings
- [x] Sprint
- [x] Crouch
- [x] Jump
- [x] Resource-driven weapon data
- [x] M1911 prototype
- [x] Hitscan firing
- [x] ADS FOV
- [x] Recoil
- [x] Magazine/reserve ammo
- [x] Reload timing
- [x] Prototype zombie
- [x] Zombie chase and melee attack
- [x] Simple obstacle steering
- [x] Headshot detection
- [x] Points/kills/headshots
- [x] Round spawning and scaling
- [x] Minimal gameplay HUD
- [x] Game-over/restart flow
- [ ] First live Godot playtest
- [ ] Tune movement feel
- [ ] Tune recoil/ADS feel
- [ ] Tune zombie speed/damage/round pacing

## Prototype 0.2: Town vertical slice

- [ ] Establish asset import conventions for GLB/glTF
- [ ] Import Town geometry/assets
- [ ] Replace graybox with Town
- [ ] Build production collision
- [ ] Add NavigationRegion3D/NavMesh workflow
- [ ] Port zombie spawn locations
- [ ] Port doors and paid gates
- [ ] Port wall buys
- [ ] Port Mystery Box
- [ ] Port perk machines
- [ ] Port Pack-a-Punch
- [ ] Port power-up drops
- [ ] Port Town ambience and gameplay audio

## Prototype 0.3: Production combat framework

- [ ] Weapon scene/socket architecture
- [ ] First-person arms
- [ ] Reload/fire/inspect animation framework
- [ ] Weapon recoil profiles
- [ ] Projectile weapons
- [ ] Wonder weapons
- [ ] PAP tiers
- [ ] Melee/knife
- [ ] Grenades
- [ ] Claymores
- [ ] Damage feedback and hit indicators

## Prototype 0.4: Character and zombie presentation

- [ ] Import Soldier character
- [ ] Skeleton/AnimationTree setup
- [ ] Weapon hand socket
- [ ] Remote third-person animation states
- [ ] Zombie production model
- [ ] Zombie animation state machine
- [ ] Brute boss model/animation
- [ ] Blood/impact effects

## Prototype 0.5: Multiplayer

First target is two players on Town while preserving the current browser/backend architecture where practical.

- [ ] Room connection layer
- [ ] Player identity
- [ ] Remote movement replication
- [ ] Weapon/fire replication
- [ ] Shared zombie state
- [ ] Points/perks/loadout sync
- [ ] Down/revive
- [ ] Reconnect/resume
- [ ] Four-player validation

## Later migration

After Town multiplayer is solid, migrate the remaining content through reusable Godot systems:

- Wayside
- Blacksire
- Last Stop
- Crossroads Day/Night
- Overpass Day/Night
- Boss rounds
- Fire Sale
- Remaining weapons/perks
- Native desktop builds
- Web export evaluation
- Dedicated server evaluation
