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

V0.3 does not implement:

- animation retargeting
- IK
- physics
- bone-level control
- complex animation blending
