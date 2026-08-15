# Production weapon preparation — Batch 3

These assets are approved production derivatives. The private purchased source
files remain outside the repository, and the original archives were not
modified. The coordinated migration promotes Benelli M4, AA-12, CheyTac M200,
and RPG-7 under truthful canonical identities while preserving M1216, the old
sniper, and War Machine as legacy compatibility resources.

## Source provenance

| Candidate | Private source | Original archive SHA-256 | Runtime derivative |
| --- | --- | --- | --- |
| Benelli M4 | Diamo Studio 45 Gun Arsenal — Shotguns / `Benelli M4` | `CDC7881DEF8276562421697262D017299B0E382011755DAEC0921F8C7AD0B197` | `diamo/benelli_m4.glb` |
| AA-12 | Diamo Studio 45 Gun Arsenal — Shotguns / `AA.12` | `CDC7881DEF8276562421697262D017299B0E382011755DAEC0921F8C7AD0B197` | `diamo/aa12.glb` |
| CheyTac M200 | Diamo Studio 45 Gun Arsenal — Snipers / `M200` | `C81BB8A85835BB6E648A0A8C5517C3048189503709A5701296A750796A20BA74` | `diamo/cheytac_m200.glb` |
| RPG-7 | Diamo Studio 45 Gun Arsenal — Launchers / `RPG-7` | `CC7A1FE05F81CDC5105439079614C3C4CCFC1ABA3B51109551B57BC167A6F740` | `diamo/rpg7.glb` |

Creator/vendor: Diamo Studio. License basis: the user-supplied purchased Diamo
Studio 45 Gun Arsenal license. Purchased source files and master 4K PBR maps
are private material and are not copied into public runtime content.

## Production preparation

- GLBs use the viewmodel convention: muzzle toward `-Z`, upright `+Y`.
- Runtime textures are capped at 2048 pixels while private 4K masters remain
  untouched. Base Color, Normal, Roughness, and Metallic response are retained.
- Benelli preserves separate bolt/charging-handle and trigger pieces, with
  bolt, loading-gate, shell insertion, and shell ejection references. The tube
  and loading gate remain embedded and are documented for later separation.
- AA-12 preserves its bolt, trigger, and side-shell carrier. The source-named
  `Mag` is truthfully named `SideShellCarrier`; the real box magazine remains
  embedded in the receiver because automatic extraction would require
  destructive, unreliable reconstruction. Reference markers define its future
  seated and removed positions.
- M200 preserves magazine, bolt handle/action, trigger, scope, and bipod as
  separate groups with animation pivots. Five zero-area source faces were
  removed from the derivative.
- RPG-7 preserves the separate rocket, corrects its origin, and supplies rocket
  seated/removed markers plus a projectile socket. Trigger and sights remain
  embedded in the launcher body.

Machine-readable hashes, counts, texture decisions, cleanup, hierarchy, pivots,
markers, and socket lists live in `reports/benelli_m4.json`, `reports/aa12.json`,
`reports/cheytac_m200.json`, and `reports/rpg7.json`.
