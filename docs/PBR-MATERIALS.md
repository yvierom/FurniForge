# Procedural PBR materials (development)

FurniForge can apply a procedural fabric or wood preset to an individual part via `furniforge_apply_parts`. Set `material` to `{ "preset": "fabric", "texture_scale_mm": 200, "roughness": 0.85 }`; use `wood` for wood. The existing `color` field tints the base texture. Scale is bounded to 10–2000 mm, roughness to 0–1, and metalness is set to zero. Omit `material` for the original solid-color behavior.

The built-in maps are synthetic repeating patterns, not material scans or PBR maps recovered from the reference image. The assistant must interpret material and color from the reference and disclose uncertainty. Texture coordinates use SketchUp defaults and can show seams or distortion on curved meshes; inspect and edit placement in SketchUp. Normal and roughness depend on SketchUp or renderer display settings. The PBR option requires SketchUp 2025 or newer; unsupported versions reject it rather than silently changing appearance. Existing RBZ releases do not include this feature until a new build is packaged.

The included RGB base and normal maps can be regenerated from the project root with `python scripts/generate_pbr_presets.py`.

