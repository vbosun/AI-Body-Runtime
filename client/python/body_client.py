from __future__ import annotations

import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_TIMEOUT_SECONDS = 10.0


@dataclass
class BodyClient:
    project_dir: Path
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

    @property
    def inbox_path(self) -> Path:
        return self.project_dir / "runtime" / "inbox" / "command.json"

    @property
    def outbox_path(self) -> Path:
        return self.project_dir / "runtime" / "outbox" / "state.json"

    def send_intent(self, command_id: str, intent: dict[str, Any]) -> dict[str, Any]:
        command = {"id": command_id, "intent": intent}
        self.inbox_path.parent.mkdir(parents=True, exist_ok=True)
        self.outbox_path.parent.mkdir(parents=True, exist_ok=True)

        if self.outbox_path.exists():
            self.outbox_path.unlink()

        temp_path = self.inbox_path.with_suffix(".tmp.json")
        temp_path.write_text(json.dumps(command, indent=2), encoding="utf-8")
        temp_path.replace(self.inbox_path)

        return self.wait_for_state(command_id)

    def wait_for_state(self, command_id: str) -> dict[str, Any]:
        deadline = time.monotonic() + self.timeout_seconds
        last_error: Exception | None = None

        while time.monotonic() < deadline:
            if self.outbox_path.exists():
                try:
                    state = json.loads(self.outbox_path.read_text(encoding="utf-8"))
                    if state.get("id") == command_id:
                        return state
                except (OSError, json.JSONDecodeError) as exc:
                    last_error = exc
            time.sleep(0.05)

        detail = f" Last read error: {last_error}" if last_error else ""
        raise TimeoutError(f"Timed out waiting for state id {command_id!r}.{detail}")


def default_project_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "godot"

