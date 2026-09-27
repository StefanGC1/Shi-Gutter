# Shit Gutter

Godot 4.6 first-person prototype. The current flow is:
**Main menu → CharacterSelector → gas-station hub → restaurant terminal → local test match → hub.**

## Getting started

1. Unzip Godot 4.6 Standard for Windows x86_64. The .NET build is not required.
2. In Godot, click **Import** and select `project.godot`.
3. Wait for models and textures to import.
4. Press **F5**, then **Singleplayer**, and pick a character to enter the hub.
5. Follow the yellow markers to the **The Last Meal** restaurant.
6. Look at the green terminal at the counter, from no more than 2.8 meters, and press **E**.
7. Choose a map at the terminal, then **Start test match**. Playground is the
   default; **CFR / Night carriage** and **Vlad Tepes / After hours** are also available.
8. From any local map, **Escape → Back to hub**.

The project uses Forward+ with Direct3D 12 on Windows and Jolt Physics.
To run an individual scene, open it and press **F6**.

## Controls

| Action | Control |
| --- | --- |
| Move | WASD or the arrow keys |
| Look | Mouse |
| Jump | Space |
| Interact with whatever you're looking at | E |
| Sit on a free toilet / stand up | E |
| Pee jet, only while seated | Hold left click; aim with the mouse |
| Start/resume a targeting round, on the training toilet | R |
| Switch character (mid-game); you return to the hub after choosing | H |
| Open/close the menu, cancel an interaction | Escape |

Menus release the cursor and block movement, jumping and mouse-look.
Player control returns automatically when a menu closes. If the player falls
below the map, they're returned to the spawn point.

## Active character

CharacterSelector offers the green character, the blue grandpa and the purple
lady. The choice used to live only in `Data.SelectPlayer` for the current
session — it's now saved to `user://save.cfg` via `Data.set_selected_character()`
and restored automatically the next time the game launches, then used in both
the hub and the playground. Each character's speed is preserved: green 5,
blue 3, purple 10. Escape from the selector returns to the main menu.

`systems/world_session.gd` creates a single `new_player`, from the chosen
character's scene, at the `PlayerSpawn` node on each map. The transform is
applied before `_ready()`, so respawning also uses the right point. To move
the starting point, move or rotate `PlayerSpawn` in the editor. Don't add a
player manually to the hub or playground: it would duplicate the controller
and camera.

The green model natively faces +Z. In the player scene it's rotated 180°, so
the face, camera and forward movement all line up on -Z. The model is raised
by 0.082764 m to put the feet at ground level; the resting camera sits at
`(0, 1.64, -0.245)`, at eye level, facing forward. The body uses visual layer
2 and isn't seen by the local camera (layer 1), to avoid seeing the inside of
the head. It stays visible in the editor and to external cameras that include
layer 2.

The `MersCaracter1` animation is used for walking. The GLB doesn't contain
dedicated idle or jump animations: the neutral standing pose is used for those
states for now. The original animations, including `Salut` and `StatToaleta`,
are kept. `systems/character_animations.gd` copies the libraries for every
instance and rebinds the tracks to the real skeleton, including after
renaming the armature with Make Local. Walking loops; `StatToaleta` plays once
and holds the seated pose. The GLB import itself doesn't need to be changed to
get runtime looping.

## Hub and entering a match

The hub is an editable draft: yard, parking lot, pumps, restaurant, toilets,
signage and collision. Every set-dressing object is a node in `hub.tscn`, so
it can be moved or swapped for final models in the editor.

Getting close to the restaurant doesn't start anything automatically. The
terminal has to be looked at up close and activated with E. The menu shows
local practice, a map selector, a player count and a confirm button.
Multiplayer is explicitly disabled: **there's no server, matchmaking queue,
network lobby or online match yet**. The hub is local-only at this stage.

Near the spawn point, on the left, the yellow **CHANGE CHARACTER** terminal
opens CharacterSelector with E. It has to be looked at up close (2.8 m max),
same as the match terminal. After choosing, you return to the hub spawn with
the new character. The H key stays available in both the hub and the
playground.

Escape opens a menu with Continue, Options (opens as an overlay on top of the
pause menu without leaving the game — pressing Back or Escape again returns to
the pause menu instead of the main menu), Back to hub (from the playground)
and Main menu.

## Integration with the team's work

### The toilet and the jet

In the hub you can use any free toilet. In the playground, to the right of the
spawn point, there's a **training toilet** facing three turquoise targets.
Look at the bowl up close and press E. The camera lowers, movement and jumping
are blocked, and the mouse controls aiming (75° left/right). Hold left click
to fire; the target flashes and counts hits. Press E again to stand up.
Standing up checks for free space for the body.

### Targeting mini-game

On the training toilet, **R** starts a **30-second** round. The duel enemy and
its toilet are hidden visually while the challenge is active, leaving only the
three targets. Hit the **yellow** target, whose active "AIM HERE" text is
highlighted green, three times for **10 points**. The
next target activates automatically; grey targets don't score. A centered HUD
at the top shows the remaining time and score versus the saved high score; the
timer turns red below 5 seconds. When the round ends, the result shows **SCORE
VS HIGH SCORE**.

The best score is now saved per practice toilet — keyed by map + node name —
to `user://save.cfg` via `Data.get_best_score()` / `Data.set_best_score()`, so
it survives leaving the map, closing the game and relaunching it, instead of
resetting on scene reload like before.

Escape freezes the timer until you continue. Standing up or respawning cancels
the round without recording a best score. Once the timer runs out, R starts a
new round. R doesn't restart a round in progress and doesn't work from other
toilets. Outside of rounds you can shoot freely, with the hit counters still
running.

The logic is isolated in `systems/practice_challenge.gd`, with the HUD in
`Scenes/practice_challenge.tscn`; the duration and hits required can be tuned
in the Inspector. It uses the targets' `hit_received(source)` signal, without
touching NPC HP or the team's global data.

### Occupancy and collisions

Toilets reserved by NPCs, including ones they're still walking to, show up as
occupied and can't be taken by the player. NPCs and the player share the same
`occupied_by` reservation. Standing up, respawning and the player being
removed all free the bowl. Escape stops the jet and opens the menu while
keeping the seat reserved; after continuing, left click has to be pressed
again. H still works to switch characters.

The jet is shared by all three characters, with ballistic droplets and
collision checks between successive positions: walls stop hits. There are
limits on droplets/splashes, and effects are cleared on pause and standing up.
The `GPUParticles3D` prototype in the green scene is kept, but disabled.
This is local gameplay only; reservations and hits aren't networked.

- **Character selector:** `Scenes/character_selection_screen.gd` calls
  `Data.set_selected_character()` (which also persists the choice) and opens
  the hub. `systems/world_session.gd` instantiates the chosen scene from
  `actors/player/` and exposes the active character through `new_player`. The
  old `$Player3D` reference was removed from the session controller. H is
  available during gameplay, not in the pause menu or at a terminal.
- **Interactions:** there's a single Input Map action, `interact`, bound to E.
  `Interactor` is a RayCast3D attached to the camera; it checks the 2.8 m
  range and the first obstacle. Walls block interaction.
- **New objects:** expose `get_interaction_prompt() -> String` and
  `interact(player)`. You can reuse `systems/interaction/interactable.gd` and
  its `activated(player)` signal. The physics body must be on layer 1 or 3;
  layer 3 is reserved for interactive objects. Don't add another global E
  handler in the toilet script.
- **Toilets:** `systems/interaction/toilet.gd` is attached to the root of
  `Scenes/Toilet.tscn`. It exposes `try_reserve(actor)`, `release(actor)`,
  `occupant()` and the `interact(actor)` contract. `seat_offset` adjusts the
  controller's position before the seating animation moves the bones.
- **Health/hits:** Both the player and the training-duel opponent now have
  real HP, via a new shared component (`systems/pee_damage.gd`, `PeeDamage` —
  same pattern as `PeeFuel`): individual droplets land far more often than
  every 0.1s, so damage isn't applied per-hit; instead, continuous exposure
  is timed and 1 HP is lost per 0.1s of being sprayed (a short grace window
  keeps a stream of droplets counted as one continuous exposure). Player3D
  has `max_health := 500.0` and a new `receive_pee_hit(source, point, normal)`
  method plus a `health_changed(fraction)` signal; `toilet_pee_duel_npc.gd`
  (the duel opponent only — NpcBunic/NpcDoamna are unaffected) has
  `max_health := 300.0`, its own `receive_pee_hit()`, and a solid purple HP bar
  with the current number drawn over the bar plus `HP: X/300` above its head.
  The duel opponent disappears at 0 HP and can only be respawned with E while
  the player is already seated on a toilet. If the player reaches 0 HP, the
  practice match ends and the player returns to the hub.
  `Scenes/health_bar_hud.tscn` — previously an orphan instanced in the
  playground with nothing driving it — now has a red player HP bar with the
  numeric `HP / MAX HP` printed on it, wired to the player's `health_changed`
  signal from `systems/world_session.gd`. NPC collisions stay active while
  seated; the duel opponent and its toilet are temporarily hidden visually
  during the local target challenge and return after the round.
- **Practice music:** the hub uses the lobby track and the test map uses the
  game track. Entering the hub switches back to the lobby music, including after
  the player is defeated and returns automatically.
- **Matchmaking/QTE:** the menu confirmation is handled in
  `systems/world_session.gd`. It currently opens the test map directly;
  matchmaking and match logic can be hooked in here later.
- **Settings & save data:** `Sigletons/data.gd` owns everything that should
  survive a restart — selected character, display mode/resolution, and every
  practice toilet's best score — loaded once at boot and written to
  `user://save.cfg` via `Data.save()` on every change. `Data.apply_display_mode()`
  /`apply_resolution()` are also called once at boot so a saved window mode and
  resolution take effect immediately. First-run defaults are Fullscreen at
  1920x1080. `menus/main_menu/options_menu.gd` reads and writes display
  mode/resolution through `Data.set_display_mode()` / `Data.set_resolution()`
  instead of touching `DisplayServer` directly, and can run both as its own
  screen (from the main menu) and embedded inside the in-game pause menu
  (`embedded_mode`). A "RESET TO DEFAULTS" button in Options (behind a
  confirmation dialog) calls `Data.reset_to_defaults()`, which wipes the
  selected character, display settings and all practice best scores back to
  first-run values and re-saves immediately — no manual save-file deletion
  needed.

## Restored story-map prototypes

- **CFR / Night carriage** (`maps/cfr_train/cfr_train.tscn`): a filthy stationary
  carriage with benches, luggage racks, stained windows/walls/ceiling, glowing
  grime and exactly two usable toilets facing each other.
- **Vlad Tepes / After hours** (`maps/vlad_tepes/vlad_tepes.tscn`): a fictional
  run-down school with a courtyard, corridor, classroom and three usable toilets.
  The ground floor is accessible; the upper floor is exterior scenery only.

Both maps reuse the selected character, existing controls, fuel and session
menus. They can also be opened directly with F6. `GepetoSpawn`/`DuelCenter` in
the train and `ErecSpawn`/`ClassroomEncounter` in the school are integration
markers, not active NPCs or missions. Architecture and set dressing are editable
scene nodes. The existing health/damage, saved settings and death-to-hub flow
are preserved; restoring maps does not revert those systems.

`systems/map_catalog.gd` supplies the terminal's map list. Materials use
`maps/shared/weathered.gdshader` without new external assets. The optional offline
builder is `tools/build_story_maps.gd`. **Regeneration overwrites both map scenes**,
including manual edits; it is not needed to play:

```text
godot --headless --path . --script res://tools/build_story_maps.gd -- --rebuild-story-maps
```

## Structure

```text
actors/characters/    The three characters and their textures
actors/player/        First-person controller and the player scene
assets/              Models, textures and the original Kenney pack
Scenes/Toilet.tscn    Toilet scene added by teammates
Scenes/character_selection_screen.tscn  Character choice
Sigletons/data.gd     Data autoload: selected character, display settings and
                      practice best scores, all persisted to user://save.cfg
maps/hub/            The gas station
maps/playground/     Test match map
maps/cfr_train/      CFR carriage prototype
maps/vlad_tepes/     Fictional school prototype
maps/shared/         Shared procedural materials
maps/test_3d/        Initial scene
menus/main_menu/     Game entry point
systems/interaction/ Shared detection/contract for interactions
systems/world_session.gd  Menus, input locking and transitions
ui/                  HUD, match menu and the Escape/pause menu (with an
                      embedded Options screen)
tests/               Automated flow checks
```

## Automated checks

After importing the project in the editor, run these from the repository root
(replace `godot` with your executable's path if it isn't on PATH):

```text
godot --headless --path . --script res://tests/hub_flow_test.gd --log-file .godot/hub-test.log
godot --headless --path . --script res://tests/toilet_flow_test.gd --log-file .godot/toilet-test.log
godot --headless --path . --script res://tests/practice_challenge_test.gd --log-file .godot/practice-test.log
godot --headless --path . --script res://tests/story_maps_test.gd --log-file .godot/story-test.log
```

The first test checks the menu → selector → hub → playground → hub → menu
path, all three characters and that speed/selection are preserved, a single
player and camera, spawning and respawning at `PlayerSpawn`, switching with H
or the character terminal (distance, prompt and being blocked during pause),
walking and jumping, close-range detection, blocking through walls, and input
being blocked in menus. On success it prints `HUB_FLOW_OK`. Camera position,
the model and the UI are additionally checked by running the game with
graphics. `TOILET_FLOW_OK` confirms the three-rig tests (bones actually
animating), isolation between two instances, shared NPC/player occupancy,
range and walls, sitting/standing, the jet, hits on target, pausing and
releasing the reservation. `PRACTICE_CHALLENGE_OK` checks real hits on all
three targets with every character, scoring, the timer running out, pausing,
resuming, cancelling and scene changes. That test resets `Data.best_scores` in
memory before it runs so leftover save data can't affect its assertions —
but any score it records during the run is still written to your real
`user://save.cfg`, the same way a normal play session would.

`STORY_MAPS_OK` checks both restored maps with all three characters, terminal
selection, walking routes, toilet orientation/interaction, collisions, options
and returning to the hub, including the current death-handling connection.

## Assets

The Kenney Animated Characters Retro pack is kept as source material, but is
no longer used by the active player. Its CC0 license is at
`assets/characters/kenney_animated_characters_retro/License.txt`. The green
character and the toilet objects are the ones added by the team.

Keep source files, `.import` files and `.uid` files in Git. The `.godot/`
folder is a locally generated cache and is ignored.
