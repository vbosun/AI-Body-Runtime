# Asset Guide

## MVP Asset Rule

The MVP should not depend on a real character model. Use primitive placeholder geometry first.

This avoids launch blockers from:

- GLB import issues
- skeleton mismatches
- animation retargeting
- material setup
- model clipping
- facial rig differences

## Placeholder Body

Recommended nodes:

```text
PlaceholderBody
├── BodyMesh
├── HeadMesh
├── LeftArmMesh
├── RightArmMesh
├── RightHandSocket
├── LeftHandSocket
├── HeadSocket
├── BackSocket
├── WaistSocket
├── HeadLookTarget
└── AnimationPlayer
```

## Test Props

Required MVP props:

- chair for `sit_chair`
- cup for `hold_cup`
- bucket for `attach_prop` socket tests
- table as the default cup location
- floor or table-side position as the default bucket location
- user anchor as the gaze target

## Future GLB Requirements

When a real GLB character is introduced, prepare:

- one exported `.glb` file
- model format must be glTF/GLB
- keep unit scale consistent with the placeholder scene
- preserve skeleton and bone names where possible
- confirm materials render correctly in Godot before mapping actions
- confirm the default imported pose is a usable standing pose
- a known rest pose
- clear skeleton naming if possible
- idle animation if available
- wave animation if available
- facial blend shapes if expression support is expected

The first real model milestone should be small: replace the placeholder body while preserving the same BodyIntent protocol.

## V0.3 Real Model Preparation

The placeholder body remains the default runtime body.

Drop the first real model here:

```text
godot/assets/characters/real_model/body.glb
```

The prepared real body scene is:

```text
godot/scenes/RealBody.tscn
```

It reserves these socket markers:

- `RightHandSocket`
- `LeftHandSocket`
- `HeadSocket`
- `BackSocket`
- `WaistSocket`

Runtime `body_mode` values:

- `placeholder`
- `real_model`

If `real_model` is requested but `body.glb` is missing or cannot be loaded, the runtime safely falls back to `placeholder`.

Real model assets are local-only development files. Do not commit `.glb` files or generated model texture files to the repository.

## Real Model Profile

V0.3 uses an in-code profile dictionary in `godot/scripts/body_runtime.gd` instead of a JSON profile file.

Each body mode can define:

- `body_scale`
- `body_position`
- `body_rotation`
- `sit_chair_position`
- `sit_chair_rotation`
- `prop_socket_offsets`

The current `real_model` profile is tuned from local screenshots:

- `sit_chair` moves the real model forward/right enough that the chair back does not fully hide it.
- `cup/right_hand` moves and scales the cup closer to the reserved hand socket.
- `bucket/head` scales the bucket down and lowers it toward the head.

V0.3 does not implement:

- animation retargeting
- IK
- physics
- bone-level control
- complex animation blending

## Animation Naming

V0.4 introduces an action slot adapter for real models. If the loaded GLB contains an `AnimationPlayer`, the runtime checks candidate animation names for each action slot and plays the first match. Recommended animation names:

- `idle`
- `wave`
- `sit_chair` or `sit_down`
- `stand_up`
- `hold_cup`

Animation sources can come from the model itself, Mixamo or FBX action libraries, BVH motion capture, Blender-authored poses or animations, or later local private animation packs. Users do not need to hand-author animations for the runtime to work: when an animation exists, BodyState reports `action_source: "animation"` and the actual `animation_name`; when it does not exist, BodyState reports `action_source: "profile_fallback"` and `animation_name: "none"`.

Keep real models, third-party animation files, generated texture files, and private animation packs out of git. Store them under gitignored local asset directories.

## V0.6 Local Animation Fixture

The first real animation test uses local files under:

```text
godot/assets_local/animations/basic/
```

Expected local files:

- `Idle.fbx`
- `Run.fbx`
- `Jump.fbx`
- `Interact.fbx`
- `wave.bvh`
- `sit_stand.bvh`

Run `godot --headless --path godot --script res://scripts/import_basic_animations.gd` to scan those files, generate `res://assets/generated/real_model/basic_animation_library.tres`, and write `res://outputs/logs/animation_debug.json`.

The committed generated library is an integration fixture with lightweight runtime tracks. It proves the action slot, `AnimationPlayer`, timing, screenshot, and `BodyState` path before the project adds a full skeleton retarget map. The original FBX/BVH files remain local and ignored.

## Skeleton Animation Tracks

For a real character limb to move, the animation must contain tracks that target the imported `Skeleton3D` or its bones. An animation that only targets `ModelRoot:position` or `ModelRoot:rotation_degrees` is useful as a playback fixture, but it will move or rotate the whole imported model instead of waving an arm.

BVH and FBX motion files must eventually be retargeted to the current character skeleton. Before doing that work, run:

```powershell
python client\python\test_action.py --launch-runtime --expect-animation wave --dump-skeleton-debug
```

The runtime writes `godot/outputs/logs/skeleton_debug.json` with:

- every detected `Skeleton3D` path
- bone counts and bone names
- every animation track path and key count
- diagnosis lines that call out root-only tracks versus skeleton/bone tracks
