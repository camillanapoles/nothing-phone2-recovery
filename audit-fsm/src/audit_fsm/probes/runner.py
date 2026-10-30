"""
Probe runner — executes read-only ADB commands after safety screening (S1, T3).

Every command passes through `safety.check_command()` before execution.
A mutating command raises `SafetyViolation` and never reaches subprocess.
Read-only commands run via subprocess with a timeout, and the output is
captured into an `Evidence` object with a provenance hash.

The runner NEVER constructs commands on its own — it receives the full command
string from the probe catalog (T3) or the orchestrator (T7). The safety guard
is the single enforcement point.
"""

from __future__ import annotations

import shlex
import shutil
import subprocess

from ..fsm.core import Evidence
from ..safety import SafetyViolation, check_command


class ProbeError(RuntimeError):
    """A probe failed to execute or returned an unexpected result."""


def resolve_adb_path() -> str:
    """Resolve the adb binary path. Checks tools/platform-tools first."""
    # 1. project-local platform-tools (Nothing Phone 2 audit environment)
    local = "/home/cnmfs/nothing-phone2/tools/platform-tools/adb"
    found = shutil.which(local)
    if found:
        return found
    # 2. system PATH
    system = shutil.which("adb")
    if system:
        return system
    raise ProbeError("adb binary not found (checked tools/platform-tools and PATH)")


def resolve_fastboot_path() -> str:
    """Resolve the fastboot binary path."""
    local = "/home/cnmfs/nothing-phone2/tools/platform-tools/fastboot"
    found = shutil.which(local)
    if found:
        return found
    system = shutil.which("fastboot")
    if system:
        return system
    raise ProbeError("fastboot binary not found")


def run_probe(
    command: str,
    *,
    timeout: int = 30,
) -> Evidence:
    """
    Execute a read-only command after safety screening.

    Args:
        command: Full command string (e.g., 'adb -s 9f51ecb9 shell getprop').
        timeout: subprocess timeout in seconds (default 30).

    Returns:
        Evidence with command, stdout, stderr, exit_code, and hash.

    Raises:
        SafetyViolation: if the command is mutating or unknown.
        ProbeError: if subprocess fails or times out.
        subprocess.TimeoutExpired: if the command exceeds the timeout.
    """
    verdict = check_command(command)
    if not verdict.allowed:
        raise SafetyViolation(
            f"refused to execute mutating/unknown command:\n"
            f"  command: {verdict.command}\n  reason: {verdict.reason}"
        )

    # Parse the command into argv — avoids shell=True injection risk.
    # The safety guard already screened the full string; shlex.split gives
    # the same binary + args without a shell intermediary.
    argv = shlex.split(command)
    try:
        result = subprocess.run(
            argv,
            check=False,
            shell=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise ProbeError(f"command timed out after {timeout}s: {command}")
    except FileNotFoundError:
        raise ProbeError(f"command binary not found: {command}")

    return Evidence(
        command=command,
        stdout=result.stdout,
        stderr=result.stderr,
        exit_code=result.returncode,
    )
