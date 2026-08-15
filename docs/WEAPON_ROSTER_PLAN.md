# Zombie Town canonical weapon roster

Updated: 2026-08-14

The coordinated production-roster migration is implemented locally and is
awaiting review before commit. Runtime identities, standard eligibility,
Mystery Box selection, Town buys, developer access, and compatibility loading
now follow this document. No legacy weapon resource has been deleted.

All manually approved HIP, ADS, and SPRINT values are final presentation
baselines. Roster work must reference those resources and must not regenerate
or overwrite them.

## Standard gameplay roster

### Conventional weapons

| Role | Weapon / ID | Production presentation |
| --- | --- | --- |
| Starting pistol | M1911 / `m1911` | DavidFalke M1911A1 |
| Assault rifle | AK-47 / `ak74u` | Approved existing CC0 asset |
| Lightweight SMG | MP7 / `mp7` | Diamo |
| Heavy SMG | UMP-45 / `ump` | Diamo |
| Modular assault rifle | HK416 / `hk416` | Diamo; successor to the old M4A1 gameplay role |
| Burst rifle | M16 / `m16` | Diamo |
| Pump shotgun | Pump Shotgun / `rem870` | Approved existing CC0 asset |
| Semi-auto shotgun | Benelli M4 / `benelli_m4` | Diamo |
| Automatic shotgun | AA-12 / `aa12` | Diamo; successor to the old M1216 role |
| Primary LMG | RPD / `rpd` | Diamo; successor to the old RPK role |
| Heavy sniper | CheyTac M200 / `m200` | Diamo; successor to the old standard sniper role |
| Box launcher | RPG-7 / `rpg7` | Diamo |

### Retained special and wonder weapons

- Flare Gun / `flaregun`
- Ballistic Knife / `bknife`
- Ray Gun / `raygun`
- Ray Gun Mark II / `raygun2`
- Thundergun / `thunder`
- Wunderwaffe DG-2 / `waffe`

The M1911 remains the starting weapon and is intentionally absent from Mystery
Box selection. All other conventional weapons above are standard Box weapons
except where Town exposes a wall buy.

## Reserve and map-specific roster

- Makarov / `makarov`: standalone identity preserving the approved former
  Makarov model and ViewmodelConfig; non-standard and developer-accessible.
- Suomi KP-31 / `mp5`: preserved for classic-themed map pools and old saves.
- M3 Grease Gun / `skorpion`: preserved for classic-themed map pools and old
  saves.
- M4A1 / `m4a1`, RPK / `rpk`, M1216 / `m1216`, and the old Sniper Rifle /
  `dsr50`: preserved legacy predecessors for developer and compatibility tests.
- Kriss Vector / `dev_vector` and CZ Scorpion EVO 3 / `dev_cz_scorpion` remain
  preferred future modern-SMG reserves. Their purchased Diamo source/model
  derivatives are not present in the current local source tree, so developer
  access currently uses clearly named procedural reserve placeholders rather
  than pretending production art is available.
- Luger and Galil remain preserved and developer-loadable, but are not preferred
  production/reserve priorities.

KSG, XM250, MG42, and other additions remain deferred until a map or distinct
gameplay role justifies them.

## Retired and legacy-only roster

M14, Olympia, War Machine, and HAMR are now non-standard and deprecated. They
are absent from both Mystery Box implementations and all active Town weapon
wall buys. Their resources remain catalogued and developer-loadable so old
inventory state can retain the original identity, ammo, order, and Pack-a-Punch
tier without receiving an unrelated replacement.

The old M14 and Olympia Town positions remain as inactive markers for a later
Town economy pass. Shared projectile, gravity, collision, splash, explosion,
and self-damage systems remain active for RPG-7 and other retained weapons.

Deleting any legacy resource or procedural presentation code requires a later,
separately authorized cleanup.

## Identity and save compatibility

Production art and gameplay identity remain truthful:

| Production model | Canonical ID |
| --- | --- |
| DavidFalke M1911A1 | `m1911` |
| Existing Makarov | `makarov` |
| Diamo HK416 | `hk416` |
| Diamo M16 | `m16` |
| Diamo RPD | `rpd` |
| Diamo Benelli M4 | `benelli_m4` |
| Diamo AA-12 | `aa12` |
| Diamo CheyTac M200 | `m200` |
| Diamo RPG-7 | `rpg7` |

Compatibility mappings for replaced standard roles are:

- `m4a1` -> `hk416`
- `rpk` -> `rpd`
- `m1216` -> `aa12`
- `dsr50` -> `m200`

`m1911` remains M1911. `mp5` and `skorpion` remain Suomi and Grease Gun.
M14, Olympia, War Machine, and HAMR retain their original legacy IDs when read
from an old inventory. See `WEAPON_SAVE_COMPATIBILITY.md` for serialized-state
details.

## Town assignments

Active weapon wall buys are MP7, AK-47, and Pump Shotgun. Active ammo walls are
M1911 and HK416. M14 and Olympia positions are inactive/unassigned. No new
replacement weapon was invented for either retired location.

## Next cleanup gate

The current working tree must be reviewed and committed before any cleanup.
Evaluation documentation, screenshots, source hashes, attribution/provenance,
purchased-source records, old WeaponData resources, and legacy production art
must remain intact until cleanup is separately authorized.
