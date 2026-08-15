# Production weapon arsenal

These are the optimized runtime derivatives used by the approved production
arsenal. Original purchased/source archives remain outside the repository.

## Batch 1

| Weapon | Runtime derivative | Source status | Runtime textures | Gameplay state |
| --- | --- | --- | --- | --- |
| M1911A1 | `m1911.glb` | DavidFalke CC Attribution production derivative; original ZIP remains outside the repository. | Gun PBR reduced from 4K masters to optimized runtime maps. | Canonical `m1911`; the former Makarov presentation is preserved separately as `makarov`. |
| MP7 | `diamo/mp7.glb` | Purchased Diamo production derivative; private source files remain outside the repository. | PBR reduced from 4K masters to optimized runtime maps. | Canonical standard `mp7`. |
| UMP | `diamo/ump.glb` | Purchased Diamo production derivative; private source files remain outside the repository. | PBR reduced from 4K masters to optimized runtime maps. | Canonical standard `ump`. |

The M1911 GLB preserves 37 separated mechanical meshes under Frame, Slide,
Magazine, and ShortRecoil groups. It includes animation pivots for trigger,
hammer, slide stop, and thumb safety, magazine-release motion metadata, and
markers for slide/magazine/hammer states. `components/` preserves one optimized
cartridge and casing derivative for later chamber/ejection animation work.

MP7 and UMP preserve separate Base, Magazine, Trigger, and Bolt meshes. The
UMP's authored scope, suppressor, and vertical grip are deliberately excluded
from the base weapon rather than permanently merged. Their masters remain in
the private source archive/evaluation derivative; future approved modular
exports can use the existing attachment layout and named sockets.

All three expose the standard optic, muzzle, underbarrel, side, stock, bayonet,
magazine, primary-grip, and support-grip sockets. Their manually approved
HIP/ADS/SPRINT ViewmodelConfigs are the production presentation baselines.

Generation reports and hashes live in `reports/`. The generated GLBs may be
recreated with `tools/blender/weapon_production_candidate_pipeline.py` and
`tools/blender/m1911_ballistics_pipeline.py` using temporary source copies.

## Attribution and provenance

### DavidFalke M1911A1

- Asset: **VR Ready: M1911A1**
- Creator: **DavidFalke**
- Source: https://sketchfab.com/3d-models/vr-ready-m1911a1-421749c3fa1744a884a340f81ab45e3c
- License: **Creative Commons Attribution**
- Original archive SHA-256: `B82936A09E20469B59C79BB195AD80B387310DCD692177BF81DD50AEC8A64D26`
- Full attribution record: `assets/weapons/evaluation/m1911_davidfalke/ATTRIBUTION.md`

### Diamo MP7 and UMP

- Library: **Diamo Studio 45 Gun Arsenal — SMGs**
- Creator/vendor: **Diamo Studio**
- Source status: user-supplied purchased archive; no license file was embedded.
- Original archive SHA-256: `B03AA1700D2E53D212C3FC2185AFD3A1C4CFA20285ECB91E9DD366B3EA9FB33C`
- Private source archive: retained outside the repository
- Full inventory/provenance: `assets/weapons/evaluation/diamo_smg/`

No purchased RAR, BLEND, FBX, OBJ, or full-resolution source texture was copied
into this runtime directory. Only optimized game-ready derivatives are present.
