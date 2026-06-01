from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from body_client import BodyClient, default_project_dir


DEFAULT_GODOT_EXE = Path(
    r"D:\Software\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64_console.exe"
)
GODOT_EXE_ENV = "AI_BODY_RUNTIME_GODOT_EXE"


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
        "expect_by_body_mode": {
            "placeholder": {
                "action_source": "placeholder_transform",
                "animation_name": "none",
            },
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
        "expect": {
            "attachments": {
                "right_hand": "cup",
            },
        },
    },
    {
        "id": "cmd_attach_cup_right_hand_001",
        "intent": {
            "action": "attach_prop",
            "expression": "smile",
            "prop": "cup",
            "target_socket": "right_hand",
            "gaze": "look_at_user",
            "camera": "front_medium",
            "screenshot": True,
        },
        "expect": {
            "attachments": {
                "right_hand": "cup",
            },
        },
    },
    {
        "id": "cmd_attach_bucket_head_001",
        "intent": {
            "action": "attach_prop",
            "expression": "surprised",
            "prop": "bucket",
            "target_socket": "head",
            "gaze": "look_at_user",
            "camera": "close_face",
            "screenshot": True,
        },
        "expect": {
            "attachments": {
                "head": "bucket",
            },
        },
    },
]

EXPECT_ANIMATION_INTENTS = {
    "idle": {
        "action": "idle",
        "expression": "neutral",
        "prop": "none",
        "gaze": "none",
        "camera": "front_medium",
        "screenshot": True,
    },
    "wave": {
        "action": "wave",
        "expression": "smile",
        "prop": "none",
        "gaze": "look_at_user",
        "camera": "front_medium",
        "screenshot": True,
    },
    "sit_chair": {
        "action": "sit_chair",
        "expression": "neutral",
        "prop": "none",
        "gaze": "look_at_user",
        "camera": "front_full",
        "screenshot": True,
    },
    "run": {
        "action": "run",
        "expression": "neutral",
        "prop": "none",
        "gaze": "none",
        "camera": "front_full",
        "screenshot": True,
    },
    "jump": {
        "action": "jump",
        "expression": "neutral",
        "prop": "none",
        "gaze": "none",
        "camera": "front_full",
        "screenshot": True,
    },
    "interact": {
        "action": "interact",
        "expression": "neutral",
        "prop": "none",
        "gaze": "look_at_user",
        "camera": "front_medium",
        "screenshot": True,
    },
}


def launch_runtime(project_dir: Path, godot_exe: Path, headless: bool = False) -> subprocess.Popen[str]:
    command = [str(godot_exe)]
    if headless:
        command.append("--headless")
    command.extend(["--path", str(project_dir)])
    return subprocess.Popen(
        command,
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


def resolve_godot_exe(cli_value: Path | None) -> Path:
    if cli_value is not None:
        return cli_value

    env_value = os.environ.get(GODOT_EXE_ENV)
    if env_value:
        return Path(env_value)

    path_value = shutil.which("godot") or shutil.which("godot4")
    if path_value:
        return Path(path_value)

    return DEFAULT_GODOT_EXE


def dump_skeleton_debug(project_dir: Path) -> bool:
    debug_path = project_dir / "outputs" / "logs" / "skeleton_debug.json"
    if not debug_path.exists():
        print(f"Missing skeleton debug log: {debug_path}", file=sys.stderr)
        return False
    data = json.loads(debug_path.read_text(encoding="utf-8"))
    skeletons = data.get("skeletons", [])
    animations = data.get("available_animations", [])
    tracks_by_animation = data.get("animation_tracks", {})
    diagnosis = data.get("diagnosis", [])

    print(f"skeleton_debug: skeletons={len(skeletons)} animations={len(animations)}")
    for skeleton in skeletons:
        bones = skeleton.get("bones", [])
        preview = ", ".join(str(name) for name in bones[:8])
        suffix = "..." if len(bones) > 8 else ""
        print(
            f"  skeleton path={skeleton.get('path')} "
            f"bone_count={skeleton.get('bone_count')} bones=[{preview}{suffix}]"
        )
    for animation_name, tracks in tracks_by_animation.items():
        print(f"  animation {animation_name}: tracks={len(tracks)}")
        for track in tracks[:4]:
            print(
                f"    #{track.get('track_index')} {track.get('type')} "
                f"path={track.get('path_text')} keys={track.get('key_count')}"
            )
    for line in diagnosis:
        print(f"  diagnosis: {line}")
    return True


def dump_bone_mapping(project_dir: Path) -> bool:
    mapping_path = project_dir / "outputs" / "logs" / "bone_mapping_candidates.json"
    if not mapping_path.exists():
        print(f"Missing bone mapping candidates log: {mapping_path}", file=sys.stderr)
        return False
    data = json.loads(mapping_path.read_text(encoding="utf-8"))
    roles = data.get("roles", {})

    print(f"bone_mapping: skeleton_path={data.get('skeleton_path')}")
    print(f"bone_mapping: bone_count={data.get('bone_count')}")
    for role_name in ["right_upper_arm", "right_lower_arm", "right_hand", "head"]:
        candidates = roles.get(role_name, {}).get("candidates", [])
        preview = ", ".join(
            f"{candidate.get('index')}:{candidate.get('name')}"
            for candidate in candidates[:8]
        )
        print(f"bone_mapping: {role_name} candidates=[{preview}]")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Run AI Body Runtime MVP action tests.")
    parser.add_argument("--project-dir", type=Path, default=default_project_dir())
    parser.add_argument(
        "--godot-exe",
        type=Path,
        default=None,
        help=f"Godot executable path. Overrides {GODOT_EXE_ENV}; otherwise PATH and the local default are tried.",
    )
    parser.add_argument("--launch-runtime", action="store_true")
    parser.add_argument(
        "--headless-runtime",
        action="store_true",
        help="Launch Godot with --headless. This is useful for protocol-only checks, but screenshots will be fallback images.",
    )
    parser.add_argument(
        "--expect-animation",
        choices=sorted(EXPECT_ANIMATION_INTENTS),
        default=None,
        help="Send one action and require real_model animation playback for it.",
    )
    parser.add_argument(
        "--dump-skeleton-debug",
        action="store_true",
        help="Require and print outputs/logs/skeleton_debug.json after the run.",
    )
    parser.add_argument(
        "--dump-bone-mapping",
        action="store_true",
        help="Require and print outputs/logs/bone_mapping_candidates.json after the run.",
    )
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()
    godot_exe = resolve_godot_exe(args.godot_exe)
    clear_runtime_files(args.project_dir)

    process: subprocess.Popen[str] | None = None
    if args.launch_runtime:
        if not godot_exe.exists():
            print(f"Godot executable not found: {godot_exe}", file=sys.stderr)
            return 2
        process = launch_runtime(args.project_dir, godot_exe, headless=args.headless_runtime)
        time.sleep(1.0)

    client = BodyClient(args.project_dir, timeout_seconds=args.timeout)
    try:
        commands = TEST_INTENTS
        if args.expect_animation is not None:
            commands = [
                {
                    "id": f"cmd_expect_animation_{args.expect_animation}",
                    "intent": EXPECT_ANIMATION_INTENTS[args.expect_animation],
                    "expect_animation": args.expect_animation,
                }
            ]
        for command in commands:
            state = client.send_intent(command["id"], command["intent"])
            print(
                f"{command['id']}: ok={state['ok']} pose={state['state']['pose']} "
                f"source={state['state'].get('action_source')} animation={state['state'].get('animation_name')} "
                f"wait={state['state'].get('animation_wait_time')} "
                f"screenshot={state['screenshot_path']}"
            )
            if not state["ok"]:
                print(state, file=sys.stderr)
                return 1
            screenshot_path = state.get("screenshot_path")
            if screenshot_path and not (args.project_dir / screenshot_path).exists():
                print(f"Missing screenshot: {screenshot_path}", file=sys.stderr)
                return 1
            body_mode = state["state"].get("body_mode")
            if (
                "action_source" not in state["state"]
                or "animation_name" not in state["state"]
                or "animation_length" not in state["state"]
                or "animation_wait_time" not in state["state"]
                or "available_animations" not in state["state"]
            ):
                print(f"Missing action adapter fields in state: {state}", file=sys.stderr)
                return 1
            if not isinstance(state["state"]["animation_length"], (int, float)):
                print(f"animation_length must be numeric: {state}", file=sys.stderr)
                return 1
            if not isinstance(state["state"]["animation_wait_time"], (int, float)):
                print(f"animation_wait_time must be numeric: {state}", file=sys.stderr)
                return 1
            if not isinstance(state["state"]["available_animations"], list):
                print(f"available_animations must be a list: {state}", file=sys.stderr)
                return 1
            if command.get("expect_animation") is not None:
                if state["state"].get("action_source") != "animation":
                    print(f"Expected animation playback, got: {state}", file=sys.stderr)
                    return 1
                if state["state"].get("animation_length", 0) <= 0:
                    print(f"Expected animation_length > 0, got: {state}", file=sys.stderr)
                    return 1
                if state["state"].get("animation_name") not in state["state"].get("available_animations", []):
                    print(f"Expected animation_name to be listed in available_animations: {state}", file=sys.stderr)
                    return 1
            if body_mode == "placeholder":
                source = state["state"].get("action_source")
                if command["intent"]["action"] in {"look_at_user", "attach_prop"}:
                    expected_sources = {"programmatic"}
                else:
                    expected_sources = {"placeholder_transform"}
                if source not in expected_sources:
                    print(f"Unexpected placeholder action_source={source}", file=sys.stderr)
                    print(state, file=sys.stderr)
                    return 1
            mode_expectations = command.get("expect_by_body_mode", {}).get(body_mode, {})
            for field_name, expected_value in mode_expectations.items():
                actual = state["state"].get(field_name)
                if actual != expected_value:
                    print(
                        f"Expected {field_name}={expected_value} for body_mode={body_mode}, got {actual}",
                        file=sys.stderr,
                    )
                    print(state, file=sys.stderr)
                    return 1
            expected_attachments = command.get("expect", {}).get("attachments", {})
            for socket_name, prop_name in expected_attachments.items():
                actual = state["state"].get("attachments", {}).get(socket_name)
                if actual != prop_name:
                    print(
                        f"Expected attachments.{socket_name}={prop_name}, got {actual}",
                        file=sys.stderr,
                    )
                    print(state, file=sys.stderr)
                    return 1
        if args.dump_skeleton_debug and not dump_skeleton_debug(args.project_dir):
            return 1
        if args.dump_bone_mapping and not dump_bone_mapping(args.project_dir):
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
