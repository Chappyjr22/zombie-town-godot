# Quaternius Ultimate Guns Pack

Source: https://quaternius.com/packs/ultimategun.html

Publisher archive: `Ultimate Gun Pack - July 2019`

License: CC0 1.0 Universal / Public Domain Dedication. The publisher's license
text is preserved in `LICENSE-CC0.txt`.

The official pack was audited in Blender 5.2 before selecting pipeline-ready
assets. It contains 40 static weapons in `.blend`, FBX, and OBJ formats, plus
15 separately authored static accessories. The Blender sources contain no
armatures or actions. Weapons and accessories are single meshes with multiple
flat-color material slots; there are no texture image files or UV-driven PBR
texture sets in this release.

## Complete weapon inventory

- Assault rifles: `AssaultRifle_1` through `AssaultRifle_5` (AK-derived
  silhouettes) and `AssaultRifle2_1` through `AssaultRifle2_4` (AR-15/M4-derived
  silhouettes).
- Bullpups: `Bullpup_1` through `Bullpup_3`.
- Pistols: `Pistol_1` through `Pistol_6`.
- Revolvers: `Revolver_1` through `Revolver_5`.
- Shotguns: `Shotgun_1` through `Shotgun_4`, `Shotgun_SawedOff`, and
  `Shotgun_ShortStock`.
- Sniper rifles: `SniperRifle_1` through `SniperRifle_6`.
- Submachine guns: `SubmachineGun_1` through `SubmachineGun_5`.

## Zombie Town candidate assessment

| Roster need | Closest pack candidate | Assessment |
| --- | --- | --- |
| MP7-style PDW | `SubmachineGun_3` | Selected as a provisional production-pipeline placeholder. Its compact PDW silhouette validates the full integration path, but its first-person detail is below Zombie Town's production-quality threshold. |
| UMP-style heavy SMG | `SubmachineGun_5` | Selected as a provisional production-pipeline placeholder. Its heavy SMG silhouette validates the full integration path, but its first-person detail is below Zombie Town's production-quality threshold. |
| M16/FAMAS-style burst rifle | `AssaultRifle2_1` | Close M16/M4-family layout, but overlaps the existing M4A1 and is not a FAMAS. Review only; do not substitute automatically. |
| RPK/LMG | `AssaultRifle_3` | Only a superficial long AK-family resemblance. It lacks the distinctive heavy barrel, bipod/drum, and LMG mass. Not recommended as the RPK production model. |
| M14/battle rifle | `SniperRifle_2` | M14 is approved for retirement. Do not substitute or source replacement art. |
| Double-barrel shotgun | `Shotgun_SawedOff`, `Shotgun_ShortStock` | Olympia is approved for retirement. Preserve these as provisional source assets only; do not promote them as replacements. |
| M1216-style shotgun | `Bullpup_1` through `Bullpup_3` | General futuristic/bullpup language only. None has the M1216's revolving tubular magazine layout. Do not substitute. |
| M1911 | `Pistol_1` / `Pistol_2` | Close classic full-frame pistol candidates with a wood-grip variant, but the slide/frame details are generic. Suitable for visual review, not an automatic replacement for the approved Makarov presentation. |

No model in this release is a convincing production LMG. The pack remains
useful for the two provisional SMGs and modular attachment architecture. M14
and Olympia candidates are no longer sourcing targets.

## Visual asset quality tiers

- **Production quality:** detailed first-person assets at least comparable to
  the current CC0 AK. These may appear in standard gameplay.
- **Provisional / placeholder:** assets that exercise the production pipeline
  and remain developer-selectable, but are held out of the standard roster
  pending higher-detail replacement art. The current Quaternius MP7 and UMP
  models are in this tier.
- **Procedural fallback:** generated geometry used when no imported visual can
  be loaded or no suitable production asset exists.

All 15 Quaternius attachment meshes are provisional. Their data resources,
catalog, layouts, sockets, and Pack-a-Punch/progression variant data homes are
production architecture and remain supported. The provisional meshes must not
be automatically attached to higher-detail production weapons.

## Attachment inventory and architecture

Every attachment is a separate one-mesh source file and remains a separate
generated GLB:

- Bayonets: `Bayonet`, `Bayonet_2` (green-grip variant).
- Support: `Bipod`, `Tripod`, `Grip` (vertical grip).
- Side accessory: `Flashlight`.
- Optics: `Scope_1`, `Scope_2`, `Scope_3`.
- Muzzle devices: `Silencer_1`, `Silencer_2`, `Silencer_3`, `Silencer_long`,
  `Silencer_Short`.
- Stock: `Stock`.

Generated weapon GLBs include standard `Socket_Optic`, `Socket_Muzzle`,
`Socket_Underbarrel`, `Socket_Side`, `Socket_Stock`, `Socket_Bayonet`,
`Socket_Magazine`, `Socket_PrimaryGrip`, and `Socket_SupportGrip` nodes.
`WeaponAttachmentData` resources describe each modular visual, while the
per-weapon `WeaponAttachmentLayout` resource keeps base, Pack-a-Punch, and named
visual-variant recipes data-driven. No runtime Gunsmith or gameplay modifier
system is enabled by this import.

## Import separation

- Untouched selected weapon sources and all attachment sources:
  `assets/weapons/quaternius/source/` (hidden from Godot with `.gdignore`).
- Generated Godot-ready assets:
  `assets/weapons/runtime/quaternius/`.
- Deterministic Blender conversion:
  `tools/blender/quaternius_asset_pipeline.py`.

The conversion uses 0.15 meters per source unit, maps the pack's +X muzzle axis
to Godot -Z forward without reflection, preserves authored flat material colors,
and places the production root near the primary grip. Viewmodel screen-space
composition remains independent in each weapon's `WeaponViewmodelProfile`.
