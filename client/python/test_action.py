from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

from body_client import BodyClient, default_project_dir


GODOT_EXE = Path(
    r"D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe"
)


TEST_INTENTS = [
    {
        "id": "cmd_idle_001",
        "intent": {
            "action": "idle",
            "expression": "neutral",
            "prop": "none",
            "gaze": "none",
            "camera": "front_medium",
            "screenshot": True,
        },
    },
    {
        "id": "cmd_wave_001",
        "intent": {
            "action": "wave",
            "expression": "smile",
            "prop": "none",
            "gaze": "look_at_user",
            "camera": "front_medium",
            "screenshot": True,
        },
    },
    {
        "id": "cmd_look_001",
        "intent": {
            "action": "look_at_user",
            "expression": "neutral",
            "prop": "none",
            "gaze": "look_at_user",
            "camera": "close_face",
            "screenshot": True,
        },
    },
    {
        "id": "cmd_sit_001",
        "intent": {
            "action": "sit_chair",
            "expression": "neutral",
            "prop": "none",
            "gaze": "look_at_user",
            "camera": "front_full",
            "screenshot": True,
        },
    },
    {
        "id": "cmd_stand_001",
        "intent": {
            "action": "stand_up",
            "expression": "neutral",
            "prop": "none",
            "gaze": "none",
            "camera": "front_full",
            "screenshot": True,
        },
    },
    {
        "id": "cmd_cup_001",
        "intent": {
            "action": "hold_cup",
            "expression": "smile",
            "prop": "cup",
            "gaze": "look_at_user",
            "camera": "front_medium",
            "screenshot": True,
        },
    },
]


def launch_runtime(project_dir: Path, godot_exe: Path) -> subprocess.Popen[str]:
    return subprocess.Popen(
        [str(godot_exe), "--headless", "--path", str(project_dir)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def clear_runtime_files(project_dir: Path) -> None:
    for path in [
        project_dir / "runtime" / "inbox" / "command.json",
        project_dir / "runtime" / "outbox" / "state.json",
    ]:
        if path.exists():
            path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run AI Body Runtime MVP action tests.")
    parser.add_argument("--project-dir", type=Path, default=default_project_dir())
    parser.add_argument("--godot-exe", type=Path, default=GODOT_EXE)
    parser.add_argument("--launch-runtime", action="store_true")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()
    clear_runtime_files(args.project_dir)

    process: subprocess.Popen[str] | None = None
    if args.launch_runtime:
        if not args.godot_exe.exists():
            print(f"Godot executable not found: {args.godot_exe}", file=sys.stderr)
            return 2
        process = launch_runtime(args.project_dir, args.godot_exe)
        time.sleep(1.0)

    client = BodyClient(args.project_dir, timeout_seconds=args.timeout)
    try:
        for command in TEST_INTENTS:
            state = client.send_intent(command["id"], command["intent"])
            print(f"{command['id']}: ok={state['ok']} pose={state['state']['pose']} screenshot={state['screenshot_path']}")
            if not state["ok"]:
                print(state, file=sys.stderr)
                return 1
            screenshot_path = state.get("screenshot_path")
            if screenshot_path and not (args.project_dir / screenshot_path).exists():
                print(f"Missing screenshot: {screenshot_path}", file=sys.stderr)
                return 1
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
