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
├── HeadLookTarget
└── AnimationPlayer
```

## Test Props

Required MVP props:

- chair for `sit_chair`
- cup for `hold_cup`
- table as the default cup location
- user anchor as the gaze target

## Future GLB Requirements

When a real GLB character is introduced, prepare:

- one exported `.glb` file
- a known rest pose
- clear skeleton naming if possible
- idle animation if available
- wave animation if available
- facial blend shapes if expression support is expected

The first real model milestone should be small: replace the placeholder body while preserving the same BodyIntent protocol.

