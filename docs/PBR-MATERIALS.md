# Procedural PBR materials (development)

FurniForge can apply a procedural fabric or wood preset to an individual part via `furniforge_apply_parts`. Set `material` to `{ "preset": "fabric", "texture_scale_mm": 200, "roughness": 0.85 }`; use `wood` for wood. The existing `color` field tints the base texture. Scale is bounded to 10–2000 mm, roughness to 0–1, and metalness is set to zero. Omit `material` for the original solid-color behavior.

The built-in maps are synthetic repeating patterns, not material scans or PBR maps recovered from the reference image. The assistant must interpret material and color from the reference and disclose uncertainty. Local-space planar mapping aligns nearby faces using the same projection, but seams can remain where the projection changes on curved meshes; inspect and edit placement in SketchUp. Normal and roughness depend on SketchUp or renderer display settings. The PBR option requires SketchUp 2025 or newer; unsupported versions reject it rather than silently changing appearance. The PBR development candidate RBZ includes these maps and the SketchUp extension changes. Use it with the matching repository source and bridge; older RBZ packages do not include this feature.

The included RGB base and normal maps can be regenerated from the project root with `python scripts/generate_pbr_presets.py`.


## Verification

In SketchUp 2026 a temporary job was created through the installed MCP server and bridge. A fabric box reported six mapped faces, PBR workflow, an enabled normal map and the requested roughness. A separate sofa test inspected 6,016 mapped faces across ten PBR parts. These checks do not establish photorealistic fidelity or full unattended background-session behavior.
