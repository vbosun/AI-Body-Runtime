# AI Body Runtime MVP Plan

## 1. Project Goal

`AI-Body-Runtime` is a local virtual body runtime that allows an existing LLM, Hermes, or Python program to control a 3D character through a strict structured protocol.

The project does **not** train a new brain. Existing LLMs are treated as the brain. This runtime provides the body layer.

Core loop:

```text
User natural language
→ LLM / Hermes understanding
→ BodyIntent JSON
→ AI-Body-Runtime executes body action
→ BodyState JSON + screenshot
```

Example user request:

```text
Sit down, hold the cup, and look at me.
```

Example BodyIntent:

```json
{
  "action": "sit_chair",
  "expression": "smile",
  "prop": "cup",
  "gaze": "look_at_user",
  "camera": "front_medium",
  "screenshot": true
}
```

Runtime result:

```text
Character sits down
→ switches expression
→ attaches cup to hand
→ looks at user
→ switches camera
→ saves screenshot
→ returns BodyState
```

---

## 2. MVP Scope

### MVP includes

The first version only validates the minimum controllable body loop:

```text
1. One placeholder virtual character
2. One test room
3. One chair
4. One cup
5. Three camera presets
6. Six body actions
7. Three expressions
8. One external control protocol
9. Screenshot output
10. Structured state return
```

### MVP does not include

To keep the project controllable, the MVP explicitly excludes:

```text
No LLM training
No skeletal reinforcement learning
No open world
No complex equipment system
No cloth physics
No arbitrary free-form body actions
No direct per-bone control from LLM
No real GLB model dependency as a launch blocker
```

The MVP goal is not visual beauty. The MVP goal is to prove:

```text
Can an existing LLM reliably control a virtual body and receive state/screenshot feedback?
```

---

## 3. Recommended Technical Direction

The recommended first implementation uses **Godot 4.x**.

Reasons:

```text
Open source
Lightweight
Good enough 3D support
Supports GLB/glTF
Easy to inspect project files
Suitable for Codex/AI coding agent workflows
Good fit for a small local runtime
```

Unity/UMA can be reconsidered later if Godot animation/IK limitations become a blocker. The MVP should not begin with Unity/UMA because the first target is protocol and runtime validation, not a large RPG avatar framework.

---

## 4. High-Level Architecture

```text
┌──────────────────────────────┐
│ User / Hermes / LLM           │
│ Language, reasoning, planning │
└───────────────┬──────────────┘
                │ BodyIntent JSON
                ▼
┌──────────────────────────────┐
│ AI-Body-Runtime               │
│ - action control              │
│ - expression control          │
│ - prop attachment             │
│ - gaze control                │
│ - camera control              │
│ - screenshot output           │
└───────────────┬──────────────┘
                │ BodyState JSON + screenshot
                ▼
┌──────────────────────────────┐
│ Client / Chat / Hermes        │
│ Display and continue dialog   │
└──────────────────────────────┘
```

The runtime is a body device. It should stay usable by different brains:

```text
Hermes
ChatGPT/OpenAI
Claude
DeepSeek
Qwen
Local LLM
Python scripts
```

---

## 5. BodyIntent Protocol

The LLM must not directly control bones. It must choose from a whitelist.

### Request

```json
{
  "action": "sit_chair",
  "expression": "smile",
  "prop": "cup",
  "gaze": "look_at_user",
  "camera": "front_medium",
  "screenshot": true
}
```

### `action` whitelist

```text
idle
look_at_user
wave
sit_chair
stand_up
hold_cup
```

### `expression` whitelist

```text
neutral
smile
surprised
```

### `prop` whitelist

```text
none
cup
```

### `gaze` whitelist

```text
none
look_at_user
```

### `camera` whitelist

```text
front_medium
front_full
close_face
```

### `screenshot`

Boolean:

```text
true / false
```

Invalid fields should be rejected or normalized to safe defaults. Unknown actions should fall back to `idle` and return an error.

---

## 6. BodyState Protocol

Example response:

```json
{
  "ok": true,
  "state": {
    "pose": "sitting",
    "action": "sit_chair",
    "expression": "smile",
    "holding": "cup",
    "gaze": "user",
    "camera": "front_medium",
    "is_busy": false,
    "last_action_status": "success"
  },
  "screenshot_path": "outputs/screenshots/20260531_000001.png",
  "errors": []
}
```

`BodyState` is used for:

```text
LLM feedback
Client display
Debugging
Replay
Future imitation learning / RL data collection
```

---

## 7. Runtime Consistency Rules

These details are important for avoiding later complexity and race conditions.

### 7.1 Synchronous blocking execution in MVP

MVP uses a synchronous blocking execution model:

```text
Receive BodyIntent
→ validate fields
→ execute action logic
→ wait until action is complete or instantly completed
→ apply expression/prop/gaze/camera
→ capture screenshot
→ write/return BodyState
```

If `sit_chair` visually takes 1.5 seconds, the MVP should wait for the action to complete before returning final state.

MVP does not support:

```text
continuous action polling
complex animation event callbacks
action queue
action cancellation
concurrent actions
async interruption
```

Future V2 may add:

```text
is_busy: true
current_action
action_progress
cancel_action
action_queue
```

### 7.2 Screenshot and BodyState are atomically bound

When `screenshot: true`, the runtime must ensure the PNG is fully written before returning/writing BodyState.

Recommended write order for file-based mode:

```text
1. Execute body action
2. Capture screenshot to temporary file:
   outputs/screenshots/cmd_001.tmp.png
3. Ensure image write is complete
4. Atomically rename to:
   outputs/screenshots/cmd_001.png
5. Write state temporary file:
   runtime/outbox/state.tmp.json
6. Atomically rename to:
   runtime/outbox/state.json
```

The client treats `state.json` as the final completion signal. When `state.json` is updated, the referenced screenshot should already be readable.

### 7.3 No animation blending in MVP

MVP does not do complex animation blending. Actions can directly override each other or reset to their required starting pose.

Example:

```text
Current state: sitting
New action: wave
MVP behavior: directly switch to waving, or reset to standing and then wave
```

The MVP requirement is correct state and stable protocol, not natural cinematic transition.

Future V2 may add:

```text
action preconditions
action transition table
AnimationTree
action queue
action interruption rules
blend weights
```

### 7.4 Every command needs command_id

File-polling mode should use unique command IDs.

Example command:

```json
{
  "id": "cmd_001",
  "intent": {
    "action": "wave",
    "expression": "smile",
    "camera": "front_medium",
    "screenshot": true
  }
}
```

Example response:

```json
{
  "id": "cmd_001",
  "ok": true,
  "state": {
    "action": "wave",
    "pose": "waving"
  },
  "screenshot_path": "outputs/screenshots/cmd_001.png",
  "errors": []
}
```

The Python client should only accept a state response whose `id` matches the current command.

### 7.5 Single-command serial execution

MVP allows only one command at a time.

If the runtime is busy and receives a new command, default behavior should be:

```text
reject new command with runtime_busy
```

Example:

```json
{
  "ok": false,
  "state": {
    "is_busy": true,
    "last_action_status": "busy"
  },
  "screenshot_path": "",
  "errors": ["runtime_busy"]
}
```

MVP does not implement:

```text
action queue
action cancellation
action preemption
multi-command concurrency
```

---

## 8. First Scene Design

### TestRoom

```text
TestRoom
├── Floor
├── Chair
├── Table
├── Cup
├── UserAnchor
└── Light
```

Meaning:

```text
Chair      target for sit_chair
Cup        prop for hold_cup
UserAnchor target for gaze/look_at_user
```

### PlaceholderBody

Use primitive geometry first:

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

This avoids blocking on:

```text
GLB import
bone mismatch
material issues
animation retargeting
model clipping
```

---

## 9. Runtime Modules

### BodyRuntime

Main coordinator.

Responsibilities:

```text
receive BodyIntent
validate fields
call controllers
collect BodyState
return result
```

### ActionController

Controls actions:

```text
idle
look_at_user
wave
sit_chair
stand_up
hold_cup
```

MVP action implementation can use simple transforms:

```text
wave       rotate right arm
sit_chair  move/lower body near chair
stand_up   restore standing height
hold_cup   attach cup to RightHandSocket
```

### ExpressionController

Controls expressions:

```text
neutral
smile
surprised
```

Placeholder stage can use simple visual markers or color/pose changes. Real character stage can use BlendShapes / Shape Keys / facial bones.

### PropController

Controls prop attachment.

MVP:

```text
cup starts on table
hold_cup attaches cup to RightHandSocket
prop=none restores cup to table
```

### GazeController

MVP:

```text
HeadMesh.look_at(UserAnchor)
```

Real character stage:

```text
head bone control
eye bone control
rotation limits
```

### CameraController

Presets:

```text
front_medium
front_full
close_face
```

### ScreenshotController

Saves current viewport to:

```text
outputs/screenshots/<command_id>.png
```

### Logger

Logs every request and response as JSONL.

Example:

```json
{
  "time": "2026-05-31T12:00:00",
  "id": "cmd_001",
  "intent": {
    "action": "wave"
  },
  "state": {
    "pose": "waving"
  },
  "screenshot_path": "outputs/screenshots/cmd_001.png",
  "errors": []
}
```

---

## 10. External Control Interface

### MVP recommendation: file polling first

Instead of starting with HTTP, MVP can use file polling:

```text
client writes:
runtime/inbox/command.json

Godot executes command

Godot writes:
runtime/outbox/state.json
```

Reasons:

```text
simpler than Godot HTTP server
easier to debug
works well for local runtime
stable enough for MVP
can later upgrade to HTTP/WebSocket
```

### command.json

```json
{
  "id": "cmd_001",
  "intent": {
    "action": "wave",
    "expression": "smile",
    "camera": "front_medium",
    "screenshot": true
  }
}
```

### state.json

```json
{
  "id": "cmd_001",
  "ok": true,
  "state": {
    "pose": "waving",
    "action": "wave",
    "expression": "smile",
    "holding": "none",
    "gaze": "user",
    "camera": "front_medium",
    "is_busy": false,
    "last_action_status": "success"
  },
  "screenshot_path": "outputs/screenshots/cmd_001.png",
  "errors": []
}
```

Later versions can add:

```text
POST /body/action
WebSocket stream
Hermes tool integration
```

---

## 11. Recommended Repository Structure

Phase 0 only creates docs and protocols:

```text
AI-Body-Runtime/
├── README.md
├── docs/
│   ├── MVP.md
│   ├── BODY_INTENT_PROTOCOL.md
│   ├── DEVELOPMENT_PLAN.md
│   ├── ASSET_GUIDE.md
│   └── TESTING.md
├── protocol/
│   ├── body_intent.schema.json
│   ├── body_state.schema.json
│   └── examples/
│       ├── idle.json
│       ├── wave.json
│       ├── sit_chair.json
│       └── hold_cup.json
```

Implementation phases can later add:

```text
├── godot/
│   ├── project.godot
│   ├── scenes/
│   ├── scripts/
│   ├── assets/
│   ├── runtime/
│   │   ├── inbox/
│   │   └── outbox/
│   └── outputs/
│       ├── screenshots/
│       └── logs/
├── client/
│   └── python/
│       ├── body_client.py
│       └── test_action.py
```

---

## 12. Development Phases

### Phase 0: Documentation and Protocol

Goal:

```text
Only docs and protocol files.
No Godot project.
No code.
```

Deliverables:

```text
README.md
docs/MVP.md
docs/BODY_INTENT_PROTOCOL.md
docs/DEVELOPMENT_PLAN.md
docs/ASSET_GUIDE.md
docs/TESTING.md
protocol/body_intent.schema.json
protocol/body_state.schema.json
protocol/examples/*.json
```

Estimated time:

```text
0.5 hour
```

### Phase 1: Godot Placeholder Project

Goal:

```text
Godot 4 project opens and runs
scene contains placeholder body, chair, cup, user anchor, cameras
```

Estimated time:

```text
1-2 hours
```

### Phase 2: Local Action Demo

Goal:

```text
Main scene automatically runs idle/wave/sit_chair/stand_up/hold_cup
BodyState printed after each action
```

Estimated time:

```text
2-4 hours
```

### Phase 3: Screenshot System

Goal:

```text
camera switching
PNG screenshot capture
screenshot_path in BodyState
```

Estimated time:

```text
1-2 hours
```

### Phase 4: File-Polling Control Interface

Goal:

```text
Python writes command.json
Godot executes
Godot writes state.json
```

Estimated time:

```text
2-4 hours
```

### Phase 5: Python Client

Goal:

```text
body_client.py
test_action.py
execute test actions from Python
```

Estimated time:

```text
1-2 hours
```

### Phase 6: LLM/Hermes Integration

Goal:

```text
LLM outputs BodyIntent JSON
Python client triggers runtime
runtime returns screenshot and state
```

Estimated time:

```text
2-4 hours
```

### Phase 7: Real GLB Character Import

Goal:

```text
import Blender-exported GLB
replace PlaceholderBody while keeping placeholder fallback
map at least idle/look_at_user/wave
```

Estimated time:

```text
0.5-2 days
```

### Phase 8: Naturalization and Extension

Goal:

```text
better animations
more props
socket attachment system
outfit presets
head bucket / hat / glasses support
```

Estimated time:

```text
2-7 days depending on asset quality
```

---

## 13. Future Socket Attachment System

The MVP only implements:

```text
cup → right_hand
```

Future versions should generalize this to a socket attachment system:

```text
right_hand
left_hand
head
back
waist
```

This enables:

```text
holding a cup
wearing glasses
wearing a hat
putting a bucket on the head
carrying an item on the back
hanging an item on the waist
```

Example future protocol:

```json
{
  "action": "attach_prop",
  "prop": "bucket",
  "target_socket": "head",
  "camera": "front_medium",
  "screenshot": true
}
```

MVP should not implement all sockets. It only validates the attachment mechanism with `cup → right_hand`.

---

## 14. Main Risks and Controls

### Risk: real model import blocks progress

Control:

```text
Use PlaceholderBody first
Real GLB begins only after runtime loop works
Keep placeholder fallback forever
```

### Risk: LLM outputs invalid commands

Control:

```text
strict whitelist
schema validation
fallback idle
errors array
```

### Risk: file race between state and screenshot

Control:

```text
write screenshot first
ensure file complete
then write state.json
client treats state.json as final signal
```

### Risk: action complexity grows too fast

Control:

```text
only 6 MVP actions
new action requires protocol update + implementation + test
```

### Risk: project drifts into full virtual life simulation

Control:

```text
MVP does not train
MVP does not do open world
MVP does not do bone-level control
MVP only validates body runtime loop
```

---

## 15. MVP Acceptance Criteria

MVP is complete when:

```text
1. Godot project can run
2. placeholder body is visible
3. idle/wave/sit_chair/stand_up/hold_cup work
4. neutral/smile/surprised can be selected
5. cup can attach to hand
6. front_medium/front_full/close_face can be selected
7. screenshot can be generated
8. external command.json can trigger an action
9. state.json is returned
10. Python client can run test actions
11. every command is logged
```

MVP does not require:

```text
beautiful animation
real model perfection
complex equipment
physical realism
reinforcement learning
```

---

## 16. Recommended Role Split

Codex / coding agent can handle:

```text
docs
protocol
Godot project files
GDScript controllers
file-polling interface
screenshot code
Python client
tests
README updates
git commits
```

Human must handle:

```text
opening Godot and verifying visual output
checking whether actions look acceptable
exporting/providing GLB assets
confirming material/bone/model quality
choosing character style
stage-by-stage acceptance
```

Expected Codex coverage:

```text
70-85% of engineering work
```

Human review remains necessary for asset and visual quality.

---

## 17. Recommended First Codex Task

```text
In the current AI-Body-Runtime repository, only create planning and protocol documents.
Do not create a Godot project.
Do not write runtime code.
Do not add project skeleton directories.

Create:
README.md
docs/MVP.md
docs/BODY_INTENT_PROTOCOL.md
docs/DEVELOPMENT_PLAN.md
docs/ASSET_GUIDE.md
docs/TESTING.md
protocol/body_intent.schema.json
protocol/body_state.schema.json
protocol/examples/idle.json
protocol/examples/wave.json
protocol/examples/sit_chair.json
protocol/examples/hold_cup.json

Commit:
git add .
git commit -m "docs: define AI body runtime MVP"
```

---

## 18. Final Assessment

The project is feasible if scoped correctly.

Correct framing:

```text
Build a controllable virtual body device for existing LLMs.
```

Incorrect framing for MVP:

```text
Train a full virtual human.
Build a Skyrim-like open-world character system.
Train bone-level body control.
```

The first technical milestone is:

```text
BodyIntent JSON
→ virtual body action
→ screenshot
→ BodyState JSON
```

Once this loop is stable, later extensions can safely add:

```text
real GLB character
animation library
socket attachment system
outfit presets
Hermes integration
data recording
imitation learning
reinforcement learning
```
