"""
Configuration — model provider settings from environment (S8, T7).

Reads these env vars (all optional, with defaults for test mode):
  AUDIT_MODEL_PROVIDER  – "test" | "google" | "openai" (default: "test")
  AUDIT_MODEL           – model identifier, e.g. "gemini-2.0-flash" (default: "test")
  AUDIT_ADB_PATH        – path to adb binary (default: resolves via probe runner)
  AUDIT_SERIAL          – device serial (default: None)

The orchestrator agent reads AUDIT_MODEL_PROVIDER/MODEL at import time so that
`audit_fsm.agents.orchestrator` can be imported in both test and production
without needing an LLM connection.
"""

from __future__ import annotations

import os


def get_model_provider() -> str:
    """Return the configured model provider (default: 'test')."""
    return os.getenv("AUDIT_MODEL_PROVIDER", "test").strip().lower()


def get_model_name() -> str:
    """Return the configured model identifier (default: 'test')."""
    return os.getenv("AUDIT_MODEL", "test").strip()


def get_adb_path() -> str:
    """Return the configured ADB path, or empty string to trigger auto-resolve."""
    return os.getenv("AUDIT_ADB_PATH", "").strip()


def get_serial() -> str:
    """Return the configured device serial, or empty string."""
    return os.getenv("AUDIT_SERIAL", "").strip()
