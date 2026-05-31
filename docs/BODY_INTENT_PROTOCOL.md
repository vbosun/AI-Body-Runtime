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
    "action": "wave",
    "expression": "smile",
    "prop": "none",
    "gaze": "look_at_user",
    "camera": "front_medium",
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

Example commands are available under `protocol/examples/`.

Allowed `expression` values:

- `neutral`
- `smile`
- `surprised`

Allowed `prop` values:

- `none`
- `cup`

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
