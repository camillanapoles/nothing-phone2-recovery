"""
Probe library — read-only ADB probes with evidence hashing (S1, S3, T3).

Exports:
  - run_probe: execute a safety-checked read-only command
  - resolve_adb_path / resolve_fastboot_path: binary resolution
  - probe_*: specific probe functions for each FSM state
  - PROBE_REGISTRY: maps FSM states to probe functions
"""

from .catalog import (
    PROBE_REGISTRY,
    probe_bootloader_state,
    probe_crash_logs,
    probe_debuggable,
    probe_device,
    probe_device_full,
    probe_gms,
    probe_gms_dumpsys,
    probe_google_packages,
    probe_kernelsu,
    probe_magisk,
    probe_partitions,
    probe_play_integrity_props,
    probe_play_store,
    probe_play_store_dumpsys,
    probe_root_packages,
    probe_selinux,
    probe_slot,
    probe_su_binary,
    probe_third_party_packages,
    probe_vendor_dlkm,
    probe_verified_boot,
)
from .runner import ProbeError, resolve_adb_path, resolve_fastboot_path, run_probe

__all__ = [
    "PROBE_REGISTRY",
    "ProbeError",
    "probe_bootloader_state",
    "probe_crash_logs",
    "probe_debuggable",
    "probe_device",
    "probe_device_full",
    "probe_gms",
    "probe_gms_dumpsys",
    "probe_google_packages",
    "probe_kernelsu",
    "probe_magisk",
    "probe_partitions",
    "probe_play_integrity_props",
    "probe_play_store",
    "probe_play_store_dumpsys",
    "probe_root_packages",
    "probe_selinux",
    "probe_slot",
    "probe_su_binary",
    "probe_third_party_packages",
    "probe_vendor_dlkm",
    "probe_verified_boot",
    "resolve_adb_path",
    "resolve_fastboot_path",
    "run_probe",
]
