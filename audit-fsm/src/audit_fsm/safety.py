"""
Safety guard — blocks any mutating command at the code level (S1, T8).

The audit is safety-first: NO mutating commands may ever be executed during an
audit. This module is the single enforcement point. Every command that the
probe library (T3) or FSM engine (T2) emits passes through `check_command()`
before execution. A mutating command raises `SafetyViolation`.

The guard is also imported in CI as a smoke test: `assert_safe()` verifies that
known mutating commands are blocked and known read-only commands are allowed.
If this ever fails, CI fails before merge.

Classification:
  - BLOCKED: fastboot flash, fastboot reboot, adb push, adb install, adb reboot,
            adb shell rm, adb shell wipe, adb shell setprop, adb remount,
            adb root, adb disable-verity, magiskinstall, etc.
  - ALLOWED: adb shell getprop, adb shell ls, adb shell cat, adb shell dumpsys,
             adb shell pm list, adb shell pm path, adb shell ps, adb shell df,
             fastboot devices, fastboot getvar, fastboot --version,
             adb devices, adb shell stat, etc.
"""

from __future__ import annotations

import re
from typing import NamedTuple


class SafetyViolation(RuntimeError):
    """A mutating command was detected. The audit refuses to execute it."""


class SafetyVerdict(NamedTuple):
    allowed: bool
    reason: str
    command: str


# ── Mutating command patterns (BLOCKED) ─────────────────────────────────

# Patterns are matched against the command string (case-insensitive).
# Each pattern is a regex that, if it matches, the command is BLOCKED.
_MUTATING_PATTERNS: list[str] = [
    # fastboot mutating
    r"fastboot\s+flash\b",
    r"fastboot\s+reboot\b",
    r"fastboot\s+oem\s+\w*\s*unlock\b",
    r"fastboot\s+oem\s+\w*\s*lock\b",
    r"fastboot\s+erase\b",
    r"fastboot\s+format\b",
    r"fastboot\s+update\b",
    r"fastboot\s+boot\b",  # booting a patched image
    r"fastboot\s+continue\b",
    r"fastboot\s+flashing\s+unlock\b",
    r"fastboot\s+flashing\s+lock\b",
    r"fastboot\s--set\b",  # --set_active slot
    # adb mutating
    r"\badb\s+push\b",
    r"\badb\s+install\b",
    r"\badb\s+uninstall\b",
    r"\badb\s+reboot\b",
    r"\badb\s+root\b",
    r"\badb\s+remount\b",
    r"\badb\s+disable-verity\b",
    r"\badb\s+enable-verity\b",
    r"\badb\s+wait-for-device\b",  # not mutating but can hang; treat as caution
    r"\badb\s+restore\b",
    r"\badb\s+backup\b",
    r"\badb\s+sideload\b",
    r"\badb\s+tcpip\b",  # changes adb mode
    # adb shell mutating subcommands
    r"\badb\s+shell\b.*\brm\b",
    r"\badb\s+shell\b.*\brmdir\b",
    r"\badb\s+shell\b.*\bmv\b",
    r"\badb\s+shell\b.*\bcp\b.*\b/\b",  # cp to a path (potential system write)
    r"\badb\s+shell\b.*\bsetprop\b",
    r"\badb\s+shell\b.*\bsettings\s+put\b",
    r"\badb\s+shell\b.*\bsettings\s+delete\b",
    r"\badb\s+shell\b.*\bpm\s+(install|uninstall|clear|enable|disable|grant|revoke)\b",
    r"\badb\s+shell\b.*\bcmd\s+package\s+(install|uninstall)\b",
    # mount with arguments (mutating); bare 'mount' and 'mount -l' are read-only
    r"\badb\s+shell\b.*\bmount\s+-o\b",  # mount -o rw /system
    r"\badb\s+shell\b.*\bmount\s+-t\b",  # mount -t ext4 /dev/...
    r"\badb\s+shell\b.*\bmount\s+/(?!tmp)\S",  # mount /dev/block/... or /system
    r"\badb\s+shell\b.*\bmount\s+-w\b",  # mount -w (writable)
    r"\badb\s+shell\b.*\bumount\b",
    r"\badb\s+shell\b.*\bmkfs\b",
    r"\badb\s+shell\b.*\bflash\b",
    r"\badb\s+shell\b.*\breboot\b",
    r"\badb\s+shell\b.*\bshutdown\b",
    r"\badb\s+shell\b.*\bsu\s+-c\b",  # running as root — caution
    r"\badb\s+shell\b.*\bdial\b.*\*",  # dialer codes (ussd)
    r"\badb\s+shell\b.*\bservice\s+call\b",
    r"\badb\s+shell\b.*\bcontent\s+insert\b",
    r"\badb\s+shell\b.*\bcontent\s+delete\b",
    r"\badb\s+shell\b.*\bcontent\s+update\b",
    r"\badb\s+shell\b.*\bwm\s+(size|density|overscan)\b",  # display changes
    r"\badb\s+shell\b.*\bifconfig\b",
    r"\badb\s+shell\b.*\bip\s+addr\b",
    r"\badb\s+shell\b.*\bchown\b",
    r"\badb\s+shell\b.*\bchmod\b",
    r"\badb\s+shell\b.*\bkillall\b",
    r"\badb\s+shell\b.*\bkill\b\s+\d",  # kill by PID
    r"\badb\s+shell\b.*\bstop\b",  # stop a service
    r"\badb\s+shell\b.*\bstart\b",  # start a service (can change state)
    # root installers
    r"\b(magisk|magiskinstall|apatch|kernelsu|ksu)\b.*\b(install|patch|flash)\b",
    # direct dd / write to block device
    r"\badb\s+shell\b.*\bdd\b.*\bof=/dev\b",
    r"\badb\s+shell\b.*\becho\b.*\b>\s*/dev\b",
    r"\badb\s+shell\b.*\becho\b.*\b>\s*/sys\b",
    r"\badb\s+shell\b.*\becho\b.*\b>\s*/proc\b",
]

_MUTATING_RE: list[re.Pattern] = [re.compile(p, re.IGNORECASE) for p in _MUTATING_PATTERNS]


# ── Known read-only command patterns (ALLOWED) ──────────────────────────

_READ_ONLY_PATTERNS: list[str] = [
    r"\badb\s+devices\b",
    r"\badb\s+shell\s+getprop\b",
    r"\badb\s+shell\s+ls\b",
    r"\badb\s+shell\s+cat\b",
    r"\badb\s+shell\s+stat\b",
    r"\badb\s+shell\s+df\b",
    r"\badb\s+shell\s+dumpsys\b",
    r"\badb\s+shell\s+pm\s+list\b",
    r"\badb\s+shell\s+pm\s+path\b",
    r"\badb\s+shell\s+ps\b",
    r"\badb\s+shell\s+id\b",
    r"\badb\s+shell\s+uname\b",
    r"\badb\s+shell\s+uptime\b",
    r"\badb\s+shell\s+w\b",
    r"\badb\s+shell\s+top\b.*-n\s+\d",  # top with limited iterations
    r"\badb\s+shell\s+date\b",
    r"\badb\s+shell\s+uptime\b",
    r"\badb\s+shell\s+getenforce\b",
    r"\badb\s+shell\s+selinuxnl\b",
    r"\badb\s+shell\s+cmd\s+package\s+list\b",
    r"\badb\s+shell\s+settings\s+get\b",
    r"\badb\s+shell\s+settings\s+list\b",
    r"\badb\s+shell\s+content\s+query\b",
    r"\badb\s+shell\s+content\s+read\b",
    r"\badb\s+shell\s+logcat\b.*-d\b",  # logcat with -d (dump, not follow)
    r"\badb\s+shell\s+logcat\b.*-b\s+\w+\s+-d\b",
    r"\badb\s+shell\s+logcat\b.*--pid\b.*-d\b",
    r"\badb\s+shell\s+wm\s+(size|density)\s*$",  # wm size with no args = read
    r"\badb\s+shell\s+service\s+list\b",
    r"\badb\s+shell\s+cmd\s+-l\b",
    r"\badb\s+shell\s+printenv\b",
    r"\badb\s+shell\s+env\b",
    r"\badb\s+shell\s+free\b",
    r"\badb\s+shell\s+mount\s*$",  # mount with no args = list
    r"\badb\s+shell\s+mount\s+-l\b",  # mount -l = list
    r"\badb\s+shell\s+du\b",
    r"\badb\s+shell\s+find\b",
    r"\badb\s+shell\s+grep\b",
    r"\badb\s+shell\s+head\b",
    r"\badb\s+shell\s+tail\b",
    r"\badb\s+shell\s+wc\b",
    r"\badb\s+shell\s+which\b",
    r"\badb\s+shell\s+file\b",
    r"\badb\s+shell\s+readlink\b",
    r"\badb\s+shell\s+ls\b.*-l\b",
    r"\badb\s+get-state\b",
    r"\badb\s+get-serialno\b",
    r"\badb\s+get-devpath\b",
    r"\badb\s+version\b",
    r"\badb\s+shell\s+getprop\s+ro\.boot\b",
    r"\badb\s+shell\s+getprop\s+ro\.build\b",
    r"\badb\s+shell\s+getprop\s+ro\.product\b",
    r"\badb\s+shell\s+getprop\s+ro\.secure\b",
    r"\badb\s+shell\s+getprop\s+ro\.debuggable\b",
    r"\badb\s+shell\s+getprop\s+ro\.bootloader\b",
    r"\badb\s+shell\s+getprop\s+ro\.boot\b.*slot",
    r"\badb\s+shell\s+getprop\s+ro\.verifiedbootstate\b",
    r"\badb\s+shell\s+getprop\s+ro\.boot\.vbmeta\b",
    r"\badb\s+shell\s+getprop\s+ro\.boot\.flash\b",
    r"\badb\s+shell\s+getprop\s+ro\.apatch\b",
    # fastboot read-only
    r"\bfastboot\s+devices\b",
    r"\bfastboot\s+getvar\b",
    r"\bfastboot\s+--version\b",
    r"\bfastboot\s+help\b",
]

_READ_ONLY_RE: list[re.Pattern] = [re.compile(p, re.IGNORECASE) for p in _READ_ONLY_PATTERNS]


# ── Core guard function ──────────────────────────────────────────────────


def _normalize_command(command: str) -> str:
    """Normalize a command so patterns match regardless of path prefix or -s serial.

    /path/to/adb -s 9f51ecb9 shell getprop → adb shell getprop
    /path/to/fastboot -s serial flash boot img → fastboot flash boot img
    """
    cmd = command.strip()
    # Replace full path to adb/fastboot with just the tool name
    cmd = re.sub(r"^\S*\badb\b", "adb", cmd)
    cmd = re.sub(r"^\S*\bfastboot\b", "fastboot", cmd)
    # Remove -s <serial> (adb/fastboot device selector)
    cmd = re.sub(r"\s+-s\s+\S+", "", cmd)
    return cmd.strip()


def check_command(command: str) -> SafetyVerdict:
    """
    Check if a command is safe (read-only) or mutating (blocked).

    Returns SafetyVerdict(allowed=True, ...) for read-only commands.
    Returns SafetyVerdict(allowed=False, ...) for mutating commands.

    Commands that match NO pattern are treated as CAUTION (blocked) —
    fail-closed is safer than fail-open for a safety-first audit.
    """
    cmd = _normalize_command(command)

    # First: check if it matches any MUTATING pattern
    for pattern in _MUTATING_RE:
        if pattern.search(cmd):
            return SafetyVerdict(
                allowed=False,
                reason=f"matches mutating pattern: {pattern.pattern}",
                command=cmd,
            )

    # Second: check if it matches a KNOWN read-only pattern
    for pattern in _READ_ONLY_RE:
        if pattern.search(cmd):
            return SafetyVerdict(
                allowed=True,
                reason=f"matches read-only pattern: {pattern.pattern}",
                command=cmd,
            )

    # Unknown command — fail closed (block by default)
    return SafetyVerdict(
        allowed=False,
        reason="unknown command — fail-closed (not in read-only allowlist)",
        command=cmd,
    )


def assert_safe() -> None:
    """
    CI smoke test: verify that known mutating commands are BLOCKED and known
    read-only commands are ALLOWED. Raises SafetyViolation if the guard is
    broken. Called from GitHub Actions CI workflow.
    """
    mutating_commands = [
        "fastboot flash boot magisk_patched.img",
        "fastboot reboot",
        "fastboot flashing unlock",
        "adb push file.zip /sdcard/",
        "adb install app.apk",
        "adb reboot bootloader",
        "adb shell rm -rf /data/media",
        "adb shell setprop ro.debuggable 1",
        "adb shell pm install /data/app.apk",
        "adb shell pm clear com.android.vending",
        "adb shell mount -o rw /system",
        "adb shell dd if=payload.bin of=/dev/block/by-name/boot",
        "adb root",
        "adb remount",
        "adb shell reboot recovery",
        "adb shell settings put global development_settings_enabled 1",
        "magisk --install-module /sdcard/module.zip",
        # Normalization: mutating commands with full paths + -s serial must be blocked
        "/home/cnmfs/nothing-phone2/tools/platform-tools/fastboot -s 9f51ecb9 flash boot magisk.img",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 push file.zip /sdcard/",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 reboot bootloader",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell rm -rf /data/media",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell setprop ro.debuggable 1",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell pm install /data/app.apk",
    ]

    read_only_commands = [
        "adb devices",
        "adb shell getprop ro.build.fingerprint",
        "adb shell getprop ro.bootloader",
        "adb shell getprop ro.boot.slot_suffix",
        "adb shell getprop ro.verifiedbootstate",
        "adb shell getprop ro.boot.vbmeta.device_state",
        "adb shell getprop ro.apatch",
        "adb shell ls -l /system/app/",
        "adb shell cat /proc/partitions",
        "adb shell df -h",
        "adb shell dumpsys package com.android.vending",
        "adb shell pm list packages -3",
        "adb shell pm path com.google.android.gms",
        "adb shell ps -A",
        "adb shell id",
        "adb shell getenforce",
        "adb shell settings get global development_settings_enabled",
        "adb shell content query --uri content://settings/global",
        "adb shell logcat -d -b crash",
        "adb shell logcat -d --pid 1234",
        "adb shell stat /dev/block/by-name/boot_a",
        "adb shell readlink /proc/self/exe",
        "fastboot devices",
        "fastboot getvar all",
        "fastboot getvar slot-count",
        "fastboot --version",
        "adb get-state",
        "adb version",
        "adb shell mount",
        "adb shell mount -l",
        "adb shell du -sh /vendor",
        # Normalization tests: full paths + -s serial must work
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb devices",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell getprop ro.build.fingerprint",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell getprop ro.boot.slot_suffix",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell getprop ro.boot.vbmeta.device_state",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell df -h",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell pm list packages -3",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell dumpsys package com.android.vending",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell getenforce",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell logcat -d -b crash",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell mount",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb -s 9f51ecb9 shell mount -l",
    ]

    for cmd in mutating_commands:
        verdict = check_command(cmd)
        if verdict.allowed:
            raise SafetyViolation(
                f"SAFETY GUARD BROKEN: mutating command allowed!\n"
                f"  command: {cmd}\n  reason: {verdict.reason}"
            )

    for cmd in read_only_commands:
        verdict = check_command(cmd)
        if not verdict.allowed:
            raise SafetyViolation(
                f"SAFETY GUARD TOO STRICT: read-only command blocked!\n"
                f"  command: {cmd}\n  reason: {verdict.reason}"
            )

    # Verify fail-closed: unknown command should be blocked
    verdict = check_command("adb shell some-unknown-command --flag")
    if verdict.allowed:
        raise SafetyViolation(
            f"SAFETY GUARD FAIL-OPEN: unknown command allowed!\n"
            f"  command: {verdict.command}\n  reason: {verdict.reason}"
        )
