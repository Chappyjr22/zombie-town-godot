# Zombie Town Asset Import Conventions

The browser game remains the visual/gameplay reference while Godot becomes the native scene and gameplay implementation.

## Source formats

- Prefer `.glb` / glTF 2.0 for production 3D assets.
- Keep editable Blender source files outside runtime scene folders when possible.
- Commit `.blend` files only when they are part of an intentional source-art workflow and not redundant downloads.
- Do not commit Godot `.godot/` import cache files.

## Coordinate and scale rules

- Godot world units are meters.
- +Y is up.
- Forward-facing character and weapon content should use -Z as forward when practical.
- Import assets at 1.0 scale whenever possible. Fix unit scale in Blender instead of compensating with large scene-node scale values.
- Apply Blender transforms before export for static environment props unless preserving an authored armature transform is required.

## Folder layout

```text
assets/
  characters/
  zombies/
  weapons/
  environments/
    town/
  props/
  textures/
  audio/
```

Reusable Godot scenes belong under `scenes/`, not inside the raw `assets/` tree.

## Static environment assets

- Prefer simple collision shapes authored in Godot for large gameplay surfaces.
- Use imported mesh collision only for irregular props where a primitive collider would noticeably change gameplay.
- Keep visual meshes and navigation source geometry separable so detailed art does not make NavMesh baking unnecessarily expensive.
- Town uses physics/static colliders as navigation bake source geometry.

## Character assets

- Keep the imported model scene untouched where practical.
- Wrap imported characters in a Godot gameplay scene that owns collision, sockets, AnimationTree, networking nodes, and game logic.
- Weapon sockets should be attached through `BoneAttachment3D` or a stable skeleton socket rather than per-frame hand-position math.

## Weapon assets

- Weapon scenes should face -Z from the muzzle.
- Keep the weapon origin near the primary grip/receiver rather than an arbitrary world origin.
- Add named muzzle and grip markers in the wrapper scene instead of embedding gameplay coordinates in weapon scripts.
- Gameplay stats stay in `WeaponData` resources, separate from the visual weapon scene.

## Blender export checklist

1. Confirm metric scale and visible dimensions.
2. Apply transforms for static meshes.
3. Confirm face normals.
4. Keep material count reasonable.
5. Name armatures, bones, and important objects predictably.
6. Export glTF 2.0 binary (`.glb`).
7. Test the GLB in an isolated Godot import scene before wiring it into gameplay.

## Web compatibility

The project currently uses Godot's Compatibility renderer so the same scene architecture can be evaluated for a future web export. Avoid renderer-specific dependencies unless the visual improvement is worth maintaining a separate native fallback.
