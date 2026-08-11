# Zombie Town Godot Migration Plan

The browser version remains supported and acts as the reference build while the Godot version is developed in parallel.

## Prototype 0.1: Core feel

Status: playable baseline

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
- [x] First live Godot playtest
- [ ] Tune movement feel
- [ ] Tune recoil/ADS feel
- [ ] Tune zombie speed/damage/round pacing

## Prototype 0.2: Town vertical slice

Status: Town structural/navigation baseline validated, gameplay systems in progress

- [x] Establish asset import conventions for GLB/glTF
- [ ] Import/refine detailed Town geometry/assets
- [x] Replace graybox with Town
- [x] Add native Godot collision for the first Town pass
- [x] Add NavigationRegion3D/NavMesh workflow
- [x] Upgrade zombies to NavigationAgent3D with steering fallback
- [x] Port player spawn and zombie spawn locations
- [x] Port Mystery Box location markers
- [x] Port wall-buy/ammo-buy location markers
- [x] Port perk location markers
- [x] Port Pack-a-Punch location marker
- [x] Port equipment-buy location markers
- [x] Validate Town scale/collision/nav in Godot
- [x] Add reusable player interaction ray/prompt framework
- [x] Add functional ammo-buy interaction for equipped ammo
- [x] Add first functional perk-machine interactions and effects
- [x] Add Pack-a-Punch tier/cost interaction hooks
- [x] Add data-driven Town wall weapon resources
- [x] Add semi-auto, automatic, pellet/spread, and shell-reload weapon behavior
- [x] Port functional Town wall-buy interactions and ammo repurchase
- [x] Carry weapon-affecting perks across weapon swaps
- [x] Add first functional Mystery Box roll/cycle/take system
- [x] Use preserved central Town Mystery Box position for prototype testing
- [x] Expand Mystery Box to supported production weapon pool
- [x] Port browser-style weighted box odds and wonder pity scaling
- [x] Slow Mystery Box cycling into final reveal
- [x] Validate expanded Mystery Box weapons in live Godot test
- [x] Add persistent two-weapon inventory and switching
- [x] Make wall buys and Mystery Box inventory aware
- [x] Make PAP tier/ammo persist per weapon slot
- [x] Make Mule Kick unlock a third weapon slot
- [x] Validate weapon-slot inventory in live Godot test
- [x] Add reusable paid gate/door progression interactable
- [x] Add paid Town entrances for Bar, Bank, Diner, General Store and Church
- [x] Link multiple Bar/Bank doorways to one building purchase so buying either opens all doors for that building
- [x] Add Bank power switch
- [x] Require Town power before Pack-a-Punch can operate
- [x] Rebuild runtime navigation when progression doors open
- [x] Validate Town paid-route and power progression in live Godot test
- [ ] Add a meaningful powered traversal shortcut when refined Town geometry supports one
- [x] Add functional Frag Grenade and Claymore wall purchases
- [x] Add reusable Max Ammo, Double Points, Insta-Kill and Nuke drop framework
- [x] Add equipment counts and active power-up HUD feedback
- [x] Add layered Frag Grenade and directional Claymore explosion effects
- [x] Validate equipment and power-up drops in live Godot test
- [x] Add reusable melee knife framework and dedicated melee scoring
- [x] Restore Ballistic Knife resource/projectile and Mystery Box weight
- [x] Validate melee and Ballistic Knife in live Godot test
- [x] Add Mystery Box teddy result, relocation and locator beam across preserved box spots
- [x] Validate Mystery Box teddy and relocation in live Godot test
- [x] Add reusable downed, bleed-out and revive player state
- [x] Make solo Quick Revive grant a timed self-revive with a three-purchase cap
- [x] Add crawl-only downed movement, interaction/combat restrictions and downed HUD feedback
- [x] Add short post-revive invulnerability window
- [x] Validate solo downed state and Quick Revive in live Godot test
- [x] Add reusable boss round every 10 rounds with a 10-zombie escort cap
- [x] Add Brute boss health scaling, heavy melee and ground-slam attack
- [x] Make the Brute resistant to Insta-Kill, Nuke and Thundergun instant-kill behavior
- [x] Add dedicated boss health bar HUD and debug-only F10 boss-round test shortcut
- [x] Validate Brute boss round in live Godot test
- [ ] Refine bar second floor, balcony, and access route
- [ ] Refine bank vault/interior
- [ ] Refine church tower/interior
- [ ] Refine diner/store interiors and props
- [ ] Add production Mystery Box model/effects/audio
- [ ] Add production perk-machine models/effects presentation
- [ ] Finish Pack-a-Punch presentation and weapon-name changes
- [ ] Port Town ambience and gameplay audio

## Prototype 0.3: Production combat framework

- [x] Reusable first-person weapon viewmodel architecture
- [x] First procedural first-person arms/hands pass
- [x] First fire/reload viewmodel animation pass
- [x] Dedicated Makarov procedural viewmodel
- [x] Dedicated AK-47 procedural viewmodel
- [x] Dedicated Galil procedural viewmodel
- [x] Dedicated Ray Gun procedural viewmodel
- [x] Dedicated Ray Gun Mark II procedural viewmodel
- [x] Class-based visual fallbacks for remaining firearms
- [x] Validate prototype viewmodel scale, hand placement, ADS and muzzle positions in live Godot tests
- [ ] Import user-provided production weapon pack and map assets to WeaponData IDs
- [ ] Replace temporary procedural viewmodels with weapon-pack scenes
- [ ] Inspect animation framework
- [x] Base weapon behavior profiles for semi/auto/shotgun wall guns
- [x] Burst-fire framework
- [x] Piercing hitscan framework
- [x] Reusable projectile framework
- [x] Flare Gun projectile/splash prototype
- [x] War Machine projectile/splash prototype
- [x] Ray Gun projectile/splash prototype
- [x] Ray Gun Mark II burst/projectile prototype
- [x] Thundergun cone-blast prototype
- [x] Wunderwaffe chain-lightning prototype
- [x] Add AN-94, Grease Gun, Luger, RPK, HAMR, M1216 and sniper box resources
- [x] Validate expanded box weapons in live Godot test
- [x] Frag grenade throw/fuse/bounce/splash prototype
- [x] Claymore placement/arming/directional blast prototype
- [x] Melee knife input/range/cooldown/viewmodel prototype
- [x] Ballistic Knife projectile prototype
- [x] Validate melee and Ballistic Knife in live Godot test
- [ ] Production weapon recoil profiles
- [ ] Production projectile/impact effects
- [ ] Production wonder weapon models/audio/effects
- [ ] Finish PAP behavior across projectile/wonder weapon attributes
- [ ] Production melee/knife model and animation
- [ ] Production grenade/Claymore models, animations and audio
- [ ] Damage feedback and hit indicators

## Prototype 0.4: Character and zombie presentation

- [ ] Import Soldier character
- [ ] Skeleton/AnimationTree setup
- [ ] Weapon hand socket
- [ ] Remote third-person animation states
- [ ] Zombie production model
- [ ] Zombie animation state machine
- [x] Temporary procedural Brute boss presentation
- [ ] Brute boss production model/animation
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
- Boss round variants/rewards
- Fire Sale
- Remaining weapons/perks
- Native desktop builds
- Web export evaluation
- Dedicated server evaluation
