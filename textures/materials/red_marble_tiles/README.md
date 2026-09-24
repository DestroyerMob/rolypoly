# Red Marble Tiles

Drag `res://materials/RedMarbleTiles.tres` from Godot's FileSystem dock onto a mesh, or assign it to the mesh's Material Override.

The material uses Godot's built-in world-space triplanar mapping so stretched box UVs and object scale do not distort the tiles. The texture repeats every 24 world units (approximately 0.5 world units per tile). Adjust all three **UV1 > Scale** components equally to resize the tiles; higher values make tiles smaller. Make the material unique before adjusting an individual object's copy. This mapping is intended for stationary architectural surfaces.

The eight supplied JPEGs are preserved without image changes. Their original filenames did not identify the texture channels, so the following roles were inferred from their appearance:

| Supplied image | Saved file | Material role |
| --- | --- | --- |
| 1 | `ambient_occlusion.jpg` | Ambient occlusion |
| 2 | `supplied_map_02.jpg` | Preserved, unused |
| 3 | `supplied_map_03.jpg` | Preserved, unused |
| 4 | `supplied_map_04.jpg` | Preserved, unused |
| 5 | `supplied_map_05.jpg` | Preserved, unused |
| 6 | `roughness.jpg` | Roughness: smoother tiles, rougher grout |
| 7 | `normal.jpg` | Tangent-space normal map, assumed OpenGL convention |
| 8 | `albedo.jpg` | Base color |

The material is nonmetallic. Displacement is disabled; the normal map supplies the surface relief.
