# Weapon save compatibility

The coordinated production-roster migration keeps serialized inventories based
on stable weapon IDs rather than `.tres` paths. `ZombieTownWeaponCatalog`
resolves replaced IDs, and `ZombieTownInventoryPlayer` serializes/restores slot
order, active slot, magazine ammo, reserve ammo, Pack-a-Punch tier, and the
Mule Kick third-slot limit.

## Explicit ID migrations

| Saved ID | Restored identity |
| --- | --- |
| `m4a1` | `hk416` |
| `rpk` | `rpd` |
| `m1216` | `aa12` |
| `dsr50` | `m200` |

`m1911` remains `m1911`; an old starting-pistol save is never reinterpreted as
Makarov ownership. Suomi KP-31 (`mp5`) and M3 Grease Gun (`skorpion`) retain
their legacy IDs because both remain usable reserve weapons.

M14, Olympia, War Machine, and HAMR also retain their original IDs when loaded
from an old inventory. Their resources remain loadable and developer-accessible
despite being excluded from new standard gameplay. This intentionally preserves
ownership and slot state instead of substituting an unrelated weapon.

If a mapped target is unavailable in a partially updated build, loading first
tries the original resource. Only an unknown/unloadable ID falls back to the
M1911 so malformed data cannot crash inventory restoration.
