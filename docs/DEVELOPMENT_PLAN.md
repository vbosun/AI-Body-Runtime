# Development Plan

## Phase 0: Documentation and Protocol

Deliverables:

- `README.md`
- `docs/MVP.md`
- `docs/BODY_INTENT_PROTOCOL.md`
- `docs/DEVELOPMENT_PLAN.md`
- `docs/ASSET_GUIDE.md`
- `docs/TESTING.md`
- `protocol/body_intent.schema.json`
- `protocol/body_state.schema.json`
- protocol examples

## Phase 1: Godot Placeholder Project

Goal:

```text
Godot 4 project opens and runs.
Scene contains placeholder body, chair, cup, user anchor, and cameras.
```

Implementation notes:

- Create the Godot project under `godot/`.
- Use primitive meshes for the placeholder body.
- Keep all runtime paths relative to the Godot project.

## Phase 2: Local Action Demo

Goal:

```text
Main scene automatically runs idle, wave, sit_chair, stand_up, and hold_cup.
BodyState is printed after each action.
```

Actions can be simple transform changes in the MVP.

## Phase 3: Screenshot System

Goal:

```text
Camera presets can be selected.
Screenshot PNG is written.
screenshot_path appears in BodyState.
```

## Phase 4: File Polling Control Interface

Goal:

```text
Python writes command.json.
Godot executes the command.
Godot writes state.json.
```

The MVP allows only one command at a time.

## Phase 5: Python Client

Goal:

```text
body_client.py can send commands and wait for matching state responses.
test_action.py can run the MVP actions.
```

## Phase 6: LLM or Hermes Integration

Goal:

```text
LLM emits BodyIntent JSON.
Python client sends it to the runtime.
Runtime returns screenshot and state.
```

## Phase 7: Real GLB Character Import

Goal:

```text
Import a Blender-exported GLB character.
Replace PlaceholderBody while keeping placeholder fallback.
Map at least idle, look_at_user, and wave.
```

Real character work begins only after the placeholder loop is stable.

