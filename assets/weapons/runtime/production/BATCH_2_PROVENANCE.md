# Production weapon preparation — Batch 2

These assets are approved production derivatives. Their private purchased
source files remain outside the repository, and the original archives were not
modified. The coordinated migration promotes HK416, M16, and RPD under truthful
canonical identities while preserving M4A1 and RPK as legacy resources.

## Source provenance

| Candidate | Private source | Original archive SHA-256 | Runtime derivative |
| --- | --- | --- | --- |
| HK416 | Diamo Studio 45 Gun Arsenal — Rifles / `HK416.A5` | `81511EEF4B8880CA2990B78F954C8D5FE55A8341252BF7176C071EC6179A4280` | `diamo/hk416.glb` |
| M16 | Diamo Studio 45 Gun Arsenal — Rifles / `M16` | `81511EEF4B8880CA2990B78F954C8D5FE55A8341252BF7176C071EC6179A4280` | `diamo/m16.glb` |
| RPD | Diamo Studio 45 Gun Arsenal — LMGs / `RPD` | `09CAB962C6C54EF8A7747BB03A9C7694F55269578901F061DCF67D304FBC1E89` | `diamo/rpd.glb` |

Creator/vendor: Diamo Studio. License basis: the user-supplied purchased Diamo
Studio 45 Gun Arsenal license. The purchased BLEND/FBX/OBJ files and master 4K
PBR textures are private source material and are not copied into public runtime
content.

## Production preparation

- GLBs use the project viewmodel convention: muzzle toward `-Z`, upright `+Y`.
- Runtime PBR maps are capped at 2048 pixels; private 4096-pixel masters remain
  untouched.
- Base Color, Normal, Roughness, and Metallic response are preserved in the
  exported GLBs. Height masters remain source-side because core glTF has no
  height channel.
- Magazine and trigger meshes remain separate on all three weapons. HK416 also
  preserves its separate stock assembly.
- Stable magazine/trigger pivots, action reference markers, and the standard
  attachment sockets are exported. RPD additionally exposes feed-cover and
  bipod preparation markers.
- Bolt and charging-handle geometry remain embedded in the source receiver
  meshes. RPD's feed cover and bipod are also embedded. The markers document
  their future animation locations without destructive or speculative mesh
  reconstruction.
- HK416 showcase optics were not merged into the base weapon. They remain in
  the private source/evaluation material for future modular attachment work.

Machine-readable per-asset conversion details, output hashes, triangle counts,
texture dimensions, hierarchy, and socket lists live in `reports/hk416.json`,
`reports/m16.json`, and `reports/rpd.json`.
