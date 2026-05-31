# Testing

## Protocol Validation

Validate:

- example commands are valid JSON
- schema files are valid JSON
- intent enum values match the documented whitelist
- state enum values match the runtime behavior

## Manual Godot Checks

For each MVP action:

1. Run the Godot project.
2. Trigger the action.
3. Confirm the body visually changes.
4. Confirm `BodyState` matches the visual state.
5. Confirm no unrelated state changes occurred.

## File Polling Checks

For each command:

1. Python writes `runtime/inbox/command.json`.
2. Godot reads the command.
3. Godot executes the action.
4. Godot writes screenshot first if requested.
5. Godot writes `runtime/outbox/state.json`.
6. Python verifies response `id` matches command `id`.

## Screenshot Checks

When `screenshot` is true:

- screenshot path is non-empty
- file exists
- file can be opened
- file belongs to the current command id
- state is written only after screenshot is ready

## Busy Runtime Check

If the runtime is executing a command and another command arrives, the MVP should return:

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

