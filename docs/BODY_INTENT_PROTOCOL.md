# Body Intent Protocol

The runtime accepts a strict whitelist protocol. LLMs and clients must not directly control bones.

## Command Envelope

File polling mode writes a command to:

```text
runtime/inbox/command.json
```

Example:

```json
{
  "id": "cmd_001",
  "intent": {
    "action": "attach_prop",
    "expression": "surprised",
    "prop": "bucket",
    "target_socket": "head",
    "gaze": "look_at_user",
    "camera": "close_face",
    "screenshot": true
  }
}
```

`id` must be unique per command. The client should only accept a response whose `id` matches the active command.

## Intent Fields

Allowed `action` values:

- `idle`
- `look_at_user`
- `wave`
- `sit_chair`
- `stand_up`
- `hold_cup`
- `attach_prop`

Example commands are available under `protocol/examples/`.

Allowed `expression` values:

- `neutral`
- `smile`
- `surprised`

Allowed `prop` values:

- `none`
- `cup`
- `bucket`

Allowed `target_socket` values:

- `right_hand`
- `left_hand`
- `head`
- `back`
- `waist`

`hold_cup` is kept for MVP compatibility and normalizes to:

```json
{
  "action": "hold_cup",
  "prop": "cup",
  "target_socket": "right_hand"
}
```

`attach_prop` attaches the selected prop to the selected socket. For example, `prop: "bucket"` and `target_socket: "head"` simulates putting a bucket on the placeholder body's head.

Allowed `gaze` values:

- `none`
- `look_at_user`

Allowed `camera` values:

- `front_medium`
- `front_full`
- `close_face`

`screenshot` is a boolean.

## Response

File polling mode writes completion state to:

```text
runtime/outbox/state.json
```

Example:

```json
{
  "id": "cmd_001",
  "ok": true,
  "state": {
    "pose": "waving",
    "body_mode": "placeholder",
    "action": "wave",
    "action_source": "placeholder_transform",
    "animation_name": "none",
    "animation_length": 0.0,
    "animation_wait_time": 0.96,
    "available_animations": [],
    "expression": "smile",
    "holding": "none",
    "attached_prop": "bucket",
    "target_socket": "head",
    "attachments": {
      "right_hand": "none",
      "left_hand": "none",
      "head": "bucket",
      "back": "none",
      "waist": "none"
    },
    "gaze": "user",
    "camera": "front_medium",
    "is_busy": false,
    "last_action_status": "success"
  },
  "screenshot_path": "outputs/screenshots/cmd_001.png",
  "errors": []
}
```

`action_source` describes how the slot was executed:

- `placeholder_transform`: placeholder mode primitive transforms
- `animation`: real model animation clip played successfully
- `profile_fallback`: real model had no matching animation, so profile transforms were used
- `programmatic`: runtime-controlled actions such as `look_at_user` or `attach_prop`

`animation_name` is the actual clip name when `action_source` is `animation`; otherwise it is `none`. `animation_length` is the detected clip length in seconds. `animation_wait_time` is the number of seconds the runtime waited before taking the screenshot; real animation waits are clamped to `0.25` through `2.0` seconds, and missing animation lengths fall back to `0.25`. `available_animations` lists animation names detected on the current real model and can be an empty array.

Real model animations may come from model-bundled clips, Mixamo/FBX action libraries, BVH motion capture, Blender-authored clips, or later local private animation packs. Recommended clip names include `idle`, `wave`, `sit_chair` or `sit_down`, `stand_up`, and `hold_cup`. If no clip exists, the protocol still succeeds through fallback behavior.

## Consistency Rules

- Unknown actions fall back to `idle` and return an error.
- Invalid fields are rejected or normalized to safe defaults.
- MVP executes one command at a time.
- If busy, the runtime returns `runtime_busy`.
- If `screenshot` is true, the PNG must be fully written before `state.json` is written.
- `state.json` is the completion signal for file polling clients.

Recommended write order:

```text
1. Execute action.
2. Capture screenshot to a temporary file.
3. Rename screenshot to final path.
4. Write state to a temporary file.
5. Rename state to final path.
```
