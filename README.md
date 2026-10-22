# RolyPoly

A physics rolling game built in Godot 4.7.

## Main menu

The game starts in `scenes/main_menu_alternative.tscn`. **Play** opens the level
selector, whose numbered slots play the level set (below) in order; slots past
the end of the set stay locked.
Use **Back** or **Escape** to close the selector. **Kitchen Gym** opens the equipment
playground; **Settings** controls menu music.

## The level list

The game's numbered levels live in `levels/` as level-editor files, and
`levels/level_order.txt` lists them one filename per line: line 1 is Level 1.
A level in the folder but missing from the file plays after the listed ones.

Manage the list from **My levels** with four buttons:

- **Add level** moves the selected saved level into `levels/`, under a filename
  made from its name, as the last numbered level.
- **Remove level** takes it out of `levels/` and back into your saved levels.
- **Move up** / **Move down** change its place in the order.

The Play menu has 16 slots. When they are full, remove a level from the list
before adding another; saved levels can still be played from **My levels**.

The Play menu picks up changes straight away. Commit `levels/` to share them;
reordering by hand is just moving lines in `level_order.txt`. These buttons write
into the project, so they only work while the game runs from the Godot editor.
Levels in the list can be edited and saved there too.

## Build and play your own levels

Run the game and choose **Level editor / My levels** from the main menu.
Choose **New level**, or select a saved course and choose **Edit** or **Play**.
To remove a saved course, select it in **My levels** and click **Delete**.

Every custom level uses the finished kitchen in
`scenes/level_editor/kitchen_interior.tscn` as its fixed base, also shared by
`scenes/kitchen.tscn`. The room, furnishings, and lighting are separate from
the demo's player and course. New courses
start on the kitchen island with a player start and a finish area. The room and
fixtures stay in place while you arrange the course. The object palette includes
counter tiles, platforms,
ramps, utensils, moving obstacles, loose produce, and all four equipment pickups:
umbrella, whipped cream, ice cube, and gravity gun.

### Default level lighting

The shared kitchen includes `scenes/lighting/kitchen_lighting.tscn` in both the
editor and gameplay, including saved courses, restarts, and the kitchen demo.
It combines low afternoon sun through the sink window, cool range-window fill,
soft shadows, subtle volumetric light shafts, and
practical lights over the island, range, bar, dining area, and vestibule.
Positional light energies account for the kitchen's 100 world units per metre.
A subdued diffuse room fill keeps shaded cabinet fronts and course edges readable
while leaving corners and the ceiling quieter than the playable surfaces.
The environment in `materials/lighting/kitchen_daylight.tres` controls ambient
light, tone mapping, contact shading, indirect light, haze, and restrained glow.
Fog distances and density also account for the room's world scale. Lighting uses
the existing renderer settings without switching viewport antialiasing at runtime.
These two resources are the places to tune the default look for every course.

Three room-sized reflection probes use box projection to keep reflections
aligned with the kitchen, bar, and vestibule. They capture the fixed room and
furnishings. The room and its captures stay loaded through edit/play switches
and restarts, so changing a course does not rebuild the room or recapture probes.
Players, moving obstacles, placement ghosts, and editor overlays stay out of
the captures. Screen-space reflections add visible course and moving details, with the
room probes providing the off-screen fallback. Probes use one-shot updates,
so the room is not rendered six extra times on every gameplay frame.
The full post-processing setup uses the project's Forward+ renderer.

### Editor controls

- The object library is a grid of model previews. Hover a tile to see its name;
  click it, then click in the world to place it. New objects stay selected so
  you can immediately resize or delete them. Choose **Place** to add another.
- Counter tiles join on an **8-unit grid**. Equipment defaults to **1-unit**
  snapping; reduce Grid snap for smaller adjustments.
- **Place on surfaces + lift** places the object's origin on the surface under
  the cursor, adding the Plane / lift Y value. Turn it off to place on a horizontal
  plane at that height. The object's pivot is preserved; adjust its position in
  the inspector when a model needs a different height.
- Hold **right mouse** to look around, **WASD** to fly, **Q/E** to descend/ascend,
  and **Shift** to fly faster. The mouse wheel moves the camera forward/backward.
- Click a placed object to select it, including while placing a new model.
  **Shift+click** places on an existing object instead. **V / Select** leaves
  placement mode. You can also use the list at the top of the inspector.
  **F** focuses the camera on the selection.
- Select **Move / G** to drag the selection along world **X / Y / Z**, or drag
  **XZ** to move across the ground plane while preserving height. Movement uses
  Grid snap; hold **Shift** while dragging for precise movement without snapping.
- Select **Rotate / R** and drag the **X / Y / Z** ring handles around the object's
  pivot to change its rotation angles. Angles snap in **15-degree** increments;
  hold **Shift** for precise rotation without snapping.
- Select **Scale / T** to drag **X / Y / Z** and scale one axis, or **↗** to scale
  all axes together. **Escape** cancels a move, rotation, or scale drag.
  Each drag is one undo step.
- Many objects have a **Properties** section in the inspector once selected: the
  blender's force, range and spin time, rolling pin and ladle speeds, masher and knife
  timings, grill and ice settings, and each gun's fire rate, pellets and spread. Changed
  values are saved with the level, show a **↺** button to restore the default, and can
  be undone. To expose another setting, add it to `scripts/level_editor/item_properties.gd`.
- Most objects also have a **Primary colour** at the top of Properties, such as the
  blender's red, the oven's enamel, a platform's grid or a funnel's body. Pick any
  colour; related shades on the same object follow it, and on textured models only
  the colourful part changes. **↺** restores the original colour. To make another
  object recolourable, list its material, mesh or shader colour in
  `scripts/level_editor/item_colours.gd`.
- **Player character** in the toolbar chooses who the level is played as (Onion, Egg,
  Tomato, Ice cream or Lollipop). The character stands on the start marker while you
  edit, and players can't swap characters during the level.
- Edit position, rotation, and scale in the inspector. **] / [** rotates
  the selected object or placement preview by 15 degrees.
- **M** moves a selected object to the next world click. **Escape** cancels.
  Duplicate and Delete are available in the inspector. **Delete / Backspace**
  removes the selected object; undo restores it.
- **Ctrl/Cmd+Z** undoes a layout change; **Ctrl/Cmd+Shift+Z** redoes it.
- **Save / Ctrl/Cmd+S** updates the current save. **Save copy** creates a separate
  course. Renaming the title and saving updates the existing course.
- **Play / Tab** runs the current layout. **Tab** returns to editing.
  Shortcuts do not override text entry in focused fields.

A playable course needs exactly one **Player start** and at least one
**Finish area**, available under the Level category. The finish is a box trigger:
change its X/Y/Z scale to fit the intended destination. Start and finish previews
are only visible in the editor; both are invisible during gameplay. A pot is a
normal kitchen object, so put a finish area inside it if it should end the level. Placing a
new start moves the single starting point. Incomplete layouts can be saved as
**drafts**, then reopened with Edit.

### Playing a custom level

Custom levels use the same character rig and equipment as the rest of the game, but
always play as the level's chosen character; the **1–5** character keys are turned
off. **WASD** to roll, **Space** to jump, **left click** to activate equipment, and
**R** to respawn. Pickups automatically connect to the
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

## Gun pickups

Three guns are available as powerups, both in the level editor palette (**M4A1**,
**Shotgun**, **Walther P88**) and in `scenes/prototyping/gun_powerups_demo.tscn`, which
has a pickup plate for each and a few eggs to shoot. Walk onto a plate to equip a gun,
then fire with the equipment button (left click). Shots are hitscan from the crosshair,
with a tracer from the gun's muzzle, and push any rigid body they hit.

| Gun | Style |
| --- | --- |
| M4A1 | Automatic: hold to fire about 11 shots a second, with a slight spread |
| Shotgun | One blast a second, 10 pellets scattered in a 5-degree cone |
| Walther P88 | Semi-automatic, about 2 shots a second, very accurate, hits harder |

All three share `scripts/gun.gd`; each `scenes/props/<gun>.tscn` just sets its numbers
(`fire_interval`, `automatic`, `pellets`, `spread_degrees`, `impulse`, and the kick and
flash effects) and a `Muzzle` marker. Connect to the `hit` signal to add damage later.
The models live under `assets/models/props/<gun>/`, muzzle facing -Z.
