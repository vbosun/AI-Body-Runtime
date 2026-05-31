# MVP

## Scope

The MVP validates the smallest controllable virtual body loop.

Included:

- one placeholder virtual character
- one test room
- one chair
- one cup
- three camera presets
- six body actions
- three expressions
- one external control protocol
- screenshot output
- structured state return
- JSONL request/response logging

Excluded:

- LLM training
- skeletal reinforcement learning
- open world behavior
- cloth physics
- arbitrary free-form body actions
- direct per-bone LLM control
- real GLB model dependency as a launch blocker

## Runtime Loop

```text
Receive BodyIntent
-> validate fields
-> execute body action
-> apply expression, prop, gaze, and camera
-> capture screenshot if requested
-> write BodyState
```

The MVP uses synchronous blocking execution. Each command completes before the final state response is written.

## Acceptance Criteria

The MVP is complete when:

1. Godot project can run.
2. Placeholder body is visible.
3. `idle`, `wave`, `sit_chair`, `stand_up`, and `hold_cup` work.
4. `neutral`, `smile`, and `surprised` can be selected.
5. Cup can attach to the right hand.
6. `front_medium`, `front_full`, and `close_face` can be selected.
7. Screenshot can be generated.
8. External `command.json` can trigger an action.
9. `state.json` is returned.
10. Python client can run test actions.
11. Every command is logged.

## Recommended MVP Scene

```text
TestRoom
├── Floor
├── Chair
├── Table
├── Cup
├── UserAnchor
└── Light

PlaceholderBody
├── BodyMesh
├── HeadMesh
├── LeftArmMesh
├── RightArmMesh
├── RightHandSocket
├── HeadLookTarget
└── AnimationPlayer
```

Placeholder geometry is preferred first so the protocol/runtime loop is not blocked by model import, bone mapping, materials, or animation retargeting.

