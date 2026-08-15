# Runtime weapon assets

This folder contains only weapon assets that are intentionally exposed to
Godot's importer.

The preserved CC0 conversion GLBs remain under `assets/weapons/cc0/`, which is
ignored by Godot. Runtime GLBs are promoted here as separate byte-identical
copies after Blender inspection. Their embedded PBR textures are extracted by
Godot beside each runtime GLB and imported as regular textures.

Pipeline:

1. Untouched CC0 source/conversion asset in `assets/weapons/cc0/`.
2. Blender background inspection for hierarchy, bounds, transforms, materials,
   texture links, cameras, lights, and animation data.
3. Separate Godot-ready GLB in this folder. Blender cleanup/export is used only
   when inspection shows it is necessary.
4. Per-weapon resource in `resources/weapons/viewmodels/` owns model correction,
   scale, HIP, ADS, SPRINT, FOV, hand, recoil, and socket data.
5. The Viewmodel Tuner performs the final screen-space alignment.

Production-quality mappings (the current detailed CC0 AK is the minimum target
for first-person art):

- `makarov.glb` -> `m1911` (approved presentation)
- `ak47.glb` -> `ak74u` (approved presentation)
- `m4a1.glb` -> `m4a1` (replaces the former `an94` gameplay slot)
- `luger.glb` -> `luger`
- `flare_gun.glb` -> `flaregun`
- `suomi_kp.glb` -> `mp5`
- `grease_gun.glb` -> `skorpion`
- `shotgun.glb` -> `rem870`
- `sniper.glb` -> `dsr50`
- `production/diamo/mp7.glb` -> `mp7` (developer-only pending manual tuner approval)
- `production/diamo/ump.glb` -> `ump` (developer-only pending manual tuner approval)
- `production/m1911.glb` -> `dev_m1911` (developer-only authentic M1911 staging resource; canonical `m1911` still uses the approved Makarov)

Preserved provisional production-pipeline assets:

- `quaternius/mp7.glb` (superseded visual placeholder retained for provenance/developer comparison)
- `quaternius/ump.glb` (superseded visual placeholder retained for provenance/developer comparison)

The Quaternius exports are generated from preserved `.blend` sources with
`tools/blender/quaternius_asset_pipeline.py`. They are authored at metric scale,
face -Z, use a primary-grip root, and include named optic, muzzle, underbarrel,
side, stock, bayonet, magazine, and hand/grip socket nodes. The pack's 15
accessories remain separate GLBs under `quaternius/attachments/`; no attachment
has been permanently merged into a weapon. These 15 visual meshes are
provisional and are not automatically attached to higher-detail production
guns. Their catalog, layouts, sockets, and future Pack-a-Punch/progression data
homes remain production architecture so individual meshes can be upgraded
without redesigning the system.

If a production model cannot be loaded, the existing procedural viewmodel path
remains the fallback. Unmatched Zombie Town weapons deliberately remain
procedural rather than receiving an unrelated pack model.
