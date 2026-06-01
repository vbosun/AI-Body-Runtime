# AI Body Runtime

AI Body Runtime is a local virtual body runtime for existing LLMs, Hermes, or Python programs.

The runtime does not train a new brain. It provides a controllable body layer:

```text
User natural language
-> LLM / Hermes understanding
-> BodyIntent JSON
-> AI Body Runtime executes body action
-> BodyState JSON + screenshot
```

The MVP target is a small Godot 4.x runtime with one placeholder character, one room, one chair, one cup, camera presets, a strict JSON protocol, screenshot output, and a Python client.

## MVP Goal

Prove that an existing LLM can reliably control a virtual body through a structured whitelist protocol and receive state/screenshot feedback.

The MVP intentionally excludes:

- LLM training
- reinforcement learning
- open-world simulation
- arbitrary bone-level control
- complex equipment systems
- real GLB model dependency as a launch blocker

## Repository Layout

```text
docs/
  MVP.md
  BODY_INTENT_PROTOCOL.md
  DEVELOPMENT_PLAN.md
  ASSET_GUIDE.md
  TESTING.md
protocol/
  body_intent.schema.json
  body_state.schema.json
  examples/
```

Implementation phases may later add:

```text
godot/
  project.godot
  scenes/
  scripts/
  runtime/
  outputs/
client/
  python/
```

## Current Recommended Stack

- Godot 4.x for the local 3D runtime
- File polling for the first external control interface
- Python for local command tests
- JSON Schema for protocol validation

## First Milestone

```text
BodyIntent JSON
-> placeholder body action
-> screenshot
-> BodyState JSON
```

## Run the Godot Runtime

Open this project in Godot:

```text
godot/project.godot
```

Or launch it from PowerShell:

```powershell
D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe --path godot
```

## Run the MVP Action Test

The Python test can launch Godot, send commands through file polling, wait for matching state responses, and verify screenshots exist. By default it launches a rendered Godot window so screenshots contain the scene. Use `--headless-runtime` only for protocol-only checks, because headless mode produces fallback screenshots without the character.

```powershell
python client\python\test_action.py --launch-runtime
```

Godot executable resolution order for `--launch-runtime`:

1. `--godot-exe`
2. `AI_BODY_RUNTIME_GODOT_EXE` environment variable
3. `godot` or `godot4` on `PATH`
4. the local Windows default path used during MVP development

Examples:

```powershell
python client\python\test_action.py --launch-runtime --godot-exe "D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe"
```

```powershell
$env:AI_BODY_RUNTIME_GODOT_EXE="D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe"
python client\python\test_action.py --launch-runtime
```

Expected output includes:

```text
cmd_idle_001: ok=True pose=standing
cmd_wave_001: ok=True pose=waving
cmd_look_001: ok=True pose=looking_at_user
cmd_sit_001: ok=True pose=sitting
cmd_stand_001: ok=True pose=standing
cmd_cup_001: ok=True pose=holding_cup
cmd_attach_cup_right_hand_001: ok=True pose=attaching_prop
cmd_attach_bucket_head_001: ok=True pose=attaching_prop
```

## Real Model Preparation

The runtime supports both `placeholder` and `real_model` body modes. The project config currently defaults to `real_model`, while the placeholder body remains available and is used as a fallback if no real model is loaded.

Place a future GLB character at:

```text
godot/assets/characters/real_model/body.glb
```

The reserved real model wrapper scene is:

```text
godot/scenes/RealBody.tscn
```

To request real model mode during local runs:

```powershell
$env:AI_BODY_RUNTIME_BODY_MODE="real_model"
python client\python\test_action.py --launch-runtime
```

If the GLB is missing, the runtime logs a warning and falls back to `placeholder`. The state response includes:

```json
{
  "body_mode": "placeholder"
}
```

V0.3 only prepares loading and socket mapping. It does not add IK, animation retargeting, physics, or bone-level control.

Real model assets are local development files and should not be committed. Files such as `body.glb` are ignored by git; keep source assets in `godot/assets/characters/real_model/` locally.

The runtime uses an in-code body profile for each body mode. The real model profile currently controls:

- body scale, position, and rotation
- `sit_chair` position and rotation
- prop/socket offsets for `cup/right_hand` and `bucket/head`

## Action Slot Animation Adapter

V0.4 adds an action slot adapter. In `real_model` mode, the runtime first looks for an `AnimationPlayer` inside the loaded GLB scene and tries to play an animation with the same name as the BodyIntent action:

- `idle`
- `wave`
- `sit_chair`
- `stand_up`
- `hold_cup`

The adapter accepts common candidate names such as `Wave`, `sit_down`, `SitDown`, `Sitting`, and `HoldCup`; animation names do not have to exactly match the action slot. `look_at_user` and `attach_prop` are treated as programmatic actions because gaze and socket attachment are runtime systems.

If no matching animation exists, the runtime uses the real model profile fallback and reports:

```json
{
  "action_source": "profile_fallback",
  "animation_name": "none",
  "animation_length": 0.0,
  "animation_wait_time": 0.2,
  "available_animations": []
}
```

V0.5 records animation playback timing. When a real animation plays, `animation_length` is the clip length in seconds and `animation_wait_time` is the clamped pre-screenshot wait time, from `0.25` to `2.0` seconds. If the animation length cannot be read, the runtime waits `0.25` seconds. Placeholder, profile fallback, and programmatic actions report `animation_length: 0.0` and use either `0.0` or the current fallback wait time.

Placeholder mode continues to use primitive transforms and reports `action_source: "placeholder_transform"`. Animation sources can come from model-bundled clips, Mixamo/FBX libraries, BVH motion capture, Blender-authored clips, or later private local animation packs. These assets should stay in gitignored local directories and should not be committed to a public repository.

## V0.6 Local Animation Test

Place local third-party animation files under:

```text
godot/assets_local/animations/basic/
```

Expected local file names for the first fixture are `Idle.fbx`, `Run.fbx`, `Jump.fbx`, `Interact.fbx`, `wave.bvh`, and `sit_stand.bvh`. They are ignored by git.

Generate the local runtime animation library:

```powershell
D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe --headless --path godot --script res://scripts/import_basic_animations.gd
```

Then run the first real animation assertion:

```powershell
python client\python\test_action.py --launch-runtime --expect-animation wave
```

The importer writes `godot/outputs/logs/animation_debug.json` with the generated `available_animations` list. The committed `.tres` fixture contains only lightweight test tracks; the original FBX/BVH files remain local.

## V0.7 Skeleton Track Debugging

If an action reports `action_source: "animation"` but the arm does not move, the animation may only affect the model root transform. V0.6's `wave` fixture proves the runtime playback path by animating `ModelRoot`, but it is not a real bone-retargeted hand wave.

Real arm motion needs animation tracks that target the imported `Skeleton3D` or its bones. Run:

```powershell
python client\python\test_action.py --launch-runtime --expect-animation wave --dump-skeleton-debug
```

The runtime writes:

```text
godot/outputs/logs/skeleton_debug.json
```

That file lists detected `Skeleton3D` nodes, bone names, animation track paths, and diagnosis lines such as `animation wave affects ModelRoot/root transform only, not skeleton bones`.

## V0.8 Bone Mapping Candidates

Before the runtime can procedurally move a real arm, it needs to know which imported bones are likely to represent the hips, torso, head, arms, hands, legs, and feet. Different GLB exporters use different names, so V0.8 does not attempt full BVH retargeting. It only scans the primary `Skeleton3D` bone names, applies lowercase keyword matching, and writes a reviewable candidate report.

Run:

```powershell
python client\python\test_action.py --launch-runtime --expect-animation wave --dump-skeleton-debug --dump-bone-mapping
```

The runtime writes:

```text
godot/outputs/logs/bone_mapping_candidates.json
```

The report includes the primary skeleton path, bone count, candidate bones per role, a sample of all bones, and diagnosis lines for roles with no match. `skeleton_debug.json` also includes `primary_skeleton_path` and `key_bone_candidates_summary`.

The committed `wave` fixture still rotates `ModelRoot:rotation_degrees`; it proves the Action Slot Animation Adapter path, but it is not skeletal arm motion by itself. The runtime now adds a lightweight procedural right-arm wave overlay for `real_model` mode using the `right_upper_arm`, `right_lower_arm`, and `right_hand` candidates. This is not BVH retargeting; it is a first visible bone-pose control path for the imported skeleton.
