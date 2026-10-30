"""
Probe catalog — read-only ADB probes for each FSM state (S1, S3, T3).

Each probe constructs a read-only command, passes it through the safety guard
(via run_probe), and returns Evidence. The probes are grouped by the FSM state
they serve:

  PROBE_DEVICE         → device properties (getprop)
  CHECK_BOOTLOADER     → bootloader lock state + slot + verified boot
  CHECK_ROOT           → root binary presence + root manager packages
  CHECK_PARTITIONS     → partition health (df -h)
  CHECK_PACKAGES       → third-party + Google packages
  CHECK_PLAY_INTEGRITY → Play Store + GMS state + crash logs

Every command here is read-only. The safety guard double-checks this before
execution — a mutating pattern in this file would raise SafetyViolation at
runtime, never reaching the device.
"""

from __future__ import annotations

from ..fsm.core import Evidence, FSMState
from .runner import run_probe


def _adb_shell(adb_path: str, serial: str, subcommand: str) -> str:
    """Build an adb shell command with -s serial."""
    return f"{adb_path} -s {serial} shell {subcommand}"


# ── PROBE_DEVICE (S3) ───────────────────────────────────────────────────


def probe_device(adb_path: str, serial: str) -> Evidence:
    """Get device properties: build fingerprint, kernel, Android version."""
    return run_probe(_adb_shell(adb_path, serial, "getprop ro.build.fingerprint"))


def probe_device_full(adb_path: str, serial: str) -> Evidence:
    """Full getprop dump for comprehensive device state."""
    return run_probe(_adb_shell(adb_path, serial, "getprop"), timeout=15)


# ── CHECK_BOOTLOADER (S3) ──────────────────────────────────────────────


def probe_bootloader_state(adb_path: str, serial: str) -> Evidence:
    """Check bootloader lock state (ro.boot.vbmeta.device_state)."""
    return run_probe(_adb_shell(adb_path, serial, "getprop ro.boot.vbmeta.device_state"))


def probe_verified_boot(adb_path: str, serial: str) -> Evidence:
    """Check verified boot state (ro.boot.verifiedbootstate)."""
    return run_probe(_adb_shell(adb_path, serial, "getprop ro.boot.verifiedbootstate"))


def probe_slot(adb_path: str, serial: str) -> Evidence:
    """Check active slot suffix (ro.boot.slot_suffix)."""
    return run_probe(_adb_shell(adb_path, serial, "getprop ro.boot.slot_suffix"))


def probe_selinux(adb_path: str, serial: str) -> Evidence:
    """Check SELinux mode (getenforce)."""
    return run_probe(_adb_shell(adb_path, serial, "getenforce"))


def probe_debuggable(adb_path: str, serial: str) -> Evidence:
    """Check if build is debuggable (ro.debuggable)."""
    return run_probe(_adb_shell(adb_path, serial, "getprop ro.debuggable"))


# ── CHECK_ROOT (S3) ────────────────────────────────────────────────────


def probe_su_binary(adb_path: str, serial: str) -> Evidence:
    """Check for su binary presence."""
    return run_probe(_adb_shell(adb_path, serial, "which su"), timeout=10)


def probe_magisk(adb_path: str, serial: str) -> Evidence:
    """Check for Magisk binary."""
    return run_probe(_adb_shell(adb_path, serial, "which magisk"), timeout=10)


def probe_kernelsu(adb_path: str, serial: str) -> Evidence:
    """Check for KernelSU binary."""
    return run_probe(_adb_shell(adb_path, serial, "which ksu"), timeout=10)


def probe_root_packages(adb_path: str, serial: str) -> Evidence:
    """List root-related packages (magisk, ksu, apatch, droidspaces)."""
    cmd = _adb_shell(
        adb_path,
        serial,
        'pm list packages | grep -iE "magisk|kernelsu|ksu|apatch|droidspaces"',
    )
    return run_probe(cmd, timeout=10)


# ── CHECK_PARTITIONS (S3) ─────────────────────────────────────────────


def probe_partitions(adb_path: str, serial: str) -> Evidence:
    """Check partition health (df -h)."""
    return run_probe(_adb_shell(adb_path, serial, "df -h"), timeout=15)


def probe_vendor_dlkm(adb_path: str, serial: str) -> Evidence:
    """Check /vendor and /vendor_dlkm free space."""
    return run_probe(_adb_shell(adb_path, serial, "df -h /vendor /vendor_dlkm"), timeout=10)


# ── CHECK_PACKAGES (S3) ────────────────────────────────────────────────


def probe_third_party_packages(adb_path: str, serial: str) -> Evidence:
    """List third-party packages."""
    return run_probe(_adb_shell(adb_path, serial, "pm list packages -3"), timeout=15)


def probe_google_packages(adb_path: str, serial: str) -> Evidence:
    """List Google-related packages."""
    return run_probe(
        _adb_shell(adb_path, serial, "pm list packages | grep -i google"),
        timeout=15,
    )


def probe_play_store(adb_path: str, serial: str) -> Evidence:
    """Check Play Store package state."""
    return run_probe(_adb_shell(adb_path, serial, "pm path com.android.vending"), timeout=10)


def probe_gms(adb_path: str, serial: str) -> Evidence:
    """Check Google Play Services package path."""
    return run_probe(_adb_shell(adb_path, serial, "pm path com.google.android.gms"), timeout=10)


# ── CHECK_PLAY_INTEGRITY (S3) ───────────────────────────────────────────


def probe_play_store_dumpsys(adb_path: str, serial: str) -> Evidence:
    """Full dumpsys for Play Store package (enabled state, permissions)."""
    return run_probe(
        _adb_shell(adb_path, serial, "dumpsys package com.android.vending"),
        timeout=15,
    )


def probe_gms_dumpsys(adb_path: str, serial: str) -> Evidence:
    """Full dumpsys for GMS package."""
    return run_probe(
        _adb_shell(adb_path, serial, "dumpsys package com.google.android.gms"),
        timeout=15,
    )


def probe_crash_logs(adb_path: str, serial: str) -> Evidence:
    """Dump crash logs (read-only — uses -d flag, not follow)."""
    return run_probe(_adb_shell(adb_path, serial, "logcat -d -b crash"), timeout=15)


def probe_play_integrity_props(adb_path: str, serial: str) -> Evidence:
    """Check Play Integrity related properties."""
    return run_probe(
        _adb_shell(adb_path, serial, "getprop ro.boot.vbmeta.device_state"),
        timeout=10,
    )


# ── Probe registry ─────────────────────────────────────────────────────

# Maps FSM states to probe functions for the orchestrator (T7).
PROBE_REGISTRY: dict[FSMState, list] = {
    FSMState.PROBE_DEVICE: [probe_device],
    FSMState.CHECK_BOOTLOADER: [
        probe_bootloader_state,
        probe_verified_boot,
        probe_slot,
        probe_selinux,
        probe_debuggable,
    ],
    FSMState.CHECK_ROOT: [
        probe_su_binary,
        probe_magisk,
        probe_kernelsu,
        probe_root_packages,
    ],
    FSMState.CHECK_PARTITIONS: [probe_partitions, probe_vendor_dlkm],
    FSMState.CHECK_PACKAGES: [
        probe_third_party_packages,
        probe_google_packages,
        probe_play_store,
        probe_gms,
    ],
    FSMState.CHECK_PLAY_INTEGRITY: [
        probe_play_store_dumpsys,
        probe_gms_dumpsys,
        probe_crash_logs,
        probe_play_integrity_props,
    ],
}
