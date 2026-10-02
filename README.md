# RolyPoly

A physics rolling game built in Godot 4.7.

## Build and play your own levels

Run the game and choose **Level editor / My levels** from the main menu.
Choose **New level**, or select a saved course and choose **Edit** or **Play**.

The editor starts with a small platform, a player start, and a finish flag.
The object palette includes the kitchen interior, counter tiles, platforms,
ramps, utensils, moving obstacles, loose produce, and all four equipment pickups:
umbrella, whipped cream, ice cube, and gravity gun.

### Editor controls

- Select an object in the palette, then click in the world to place it.
- Counter tiles join on an **8-unit grid**. Equipment defaults to **1-unit**
  snapping; reduce Grid snap for smaller adjustments.
- **Place on surfaces + lift** places the object's origin on the surface under
  the cursor, adding the Plane / lift Y value. Turn it off to place on a horizontal
  plane at that height. The object's pivot is preserved; adjust its position in
  the inspector when a model needs a different height.
- Hold **right mouse** to look around, **WASD** to fly, **Q/E** to descend/ascend,
  and **Shift** to fly faster. The mouse wheel moves the camera forward/backward.
- **V / Select** selects existing objects. You can also use the list of placed
  objects at the top of the inspector. **F** focuses the camera on the selection.
- Edit position, rotation, and scale in the inspector. **R / Shift+R** rotates
  the selected object or placement preview by 15 degrees.
- **M** moves a selected object to the next world click. **Escape** cancels.
  Duplicate and Delete are available in the inspector.
- **Ctrl/Cmd+Z** undoes a layout change; **Ctrl/Cmd+Shift+Z** redoes it.
- **Save / Ctrl/Cmd+S** updates the current save. **Save copy** creates a separate
  course. Renaming the title and saving updates the existing course.
- **Play / Tab** runs the current layout. **Tab** returns to editing.
  Shortcuts do not override text entry in focused fields.

A playable course needs exactly one **Player start** and at least one
**Finish flag** or **Finish pot**, available under the Level category. Placing a
new start moves the single starting point. Incomplete layouts can be saved as
**drafts**, then reopened with Edit.

### Playing a custom level

Custom levels use the same character rig and equipment as the rest of the game:
**WASD** to roll, **Space** to jump, **1–5** to change character, **left click** to
activate equipment, and **R** to respawn. Pickups automatically connect to the
active character's equipment mount. Falling below the course respawns the player.

**Escape** pauses physics and opens Resume, Restart, Edit, My levels, and Main
menu. Reaching a finish shows the completion menu. Restarting or returning to
Edit reconstructs the original layout, including moving obstacles and loose
objects; gameplay never changes the authored transforms.

### Saves

Courses are versioned JSON files in Godot's `user://levels/` directory. They remain
available after quitting the game. On macOS the default location is:

`~/Library/Application Support/Godot/app_userdata/RolyPoly/levels/`

To move a course to another installation, copy its JSON file into that game's
`user://levels/` folder. The browser shows malformed or unsupported files with an
error instead of trying to instantiate them. Scene IDs come from the built-in
catalog; save files cannot supply arbitrary resource paths or scripts.

The reusable player scene is `res://scenes/custom_level.tscn`; the editor scene is
`res://scenes/level_builder.tscn`. Either can open a saved filename from a local
shortcut or command line, for example:

```sh
godot --path /path/to/roly-poly res://scenes/custom_level.tscn -- --custom-level=level_filename.json
```

The filename is relative to `user://levels/`. Without that argument, running the
player scene directly uses the starter layout. Normal players can use My levels
from the game's main menu.
