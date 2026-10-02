# Styling the menu kitchen

Open `kitchen_set.tscn` to edit the kitchen. Preview the result in
`../main_menu_alternative.tscn` for the menu cameras and lighting.

- **Room** contains the floor, ceiling, and main walls.
- **Fixtures** contains the island, cooking range, counters, sink wall, and pantry.
- **Furniture** contains the table and chair.
- **Props** contains the rug, pendant shade, and power outlet.

Select a `Mesh`, `CabinetBody`, or `Countertop` node and assign a material under
**Surface Material Override → 0**. These meshes are saved in the scene; prototype
scripts no longer rebuild them or reset their finishes. The sink's window wall is
CSG: set the material on `Fixtures/SinkWall/WindowWall/Wall`.

The named resources in `materials/menu_kitchen/` control matching surfaces across
the kitchen. They start with neutral placeholder finishes. Edit a resource for a
kitchen-wide change, or use a surface override for a single object. Use **Make
Unique** before modifying a shared material when only one object should change.
Imported furniture and appliance instances have editable children enabled; expand
them to reach their meshes and material slots.

The marble wall is overridden in the menu at `KitchenStudio/Room/RangeWall/Mesh`.
Change that override when styling the menu's backsplash. The menu also retains its
own oven placement, hood lighting, and hidden background blender.

Move a mesh's parent body to reposition the object together with its collision.
If you resize a mesh resource, update its sibling `Collision` shape as well.
Cabinet bodies and countertops are separate meshes with a shared full-size collider.
