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

The Python test can launch Godot headless, send commands through file polling, wait for matching state responses, and verify screenshots exist.

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

The runtime defaults to `placeholder` mode. V0.3 adds a safe `real_model` preparation path without replacing the placeholder body.

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
