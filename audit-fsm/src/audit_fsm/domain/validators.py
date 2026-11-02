"""
Additional validators for domain models (S7, T4).

Pure functions — no hardcoded literals. Each accepts a raw value and returns
the validated value or raises ValidationError.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from .metaclass import ValidationError, validate_int, validate_nonempty

# ── UUID ─────────────────────────────────────────────────────────────────

_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.IGNORECASE
)


def validate_uuid(value: Any) -> str:
    """Validate a UUID4-format string (8-4-4-4-12 hex)."""
    v = validate_nonempty(value)
    if not _UUID_RE.match(v):
        raise ValidationError("uuid", value, "must be a UUID-format string (8-4-4-4-12 hex)")
    return v.lower()


# ── Device serial ────────────────────────────────────────────────────────

_SERIAL_RE = re.compile(r"^[0-9a-f]{8,}$", re.IGNORECASE)


def validate_serial(value: Any) -> str:
    """Validate a device serial number (8+ alphanumeric chars)."""
    v = validate_nonempty(value)
    if not _SERIAL_RE.match(v):
        raise ValidationError("serial", value, "must be 8+ alphanumeric chars")
    return v.lower()


# ── ISO timestamp ────────────────────────────────────────────────────────


def validate_timestamp(value: Any) -> str:
    """Validate an ISO 8601 timestamp string."""
    v = validate_nonempty(value)
    try:
        datetime.fromisoformat(v)
    except ValueError:
        raise ValidationError("timestamp", value, "must be ISO 8601 format")
    return v


# ── Non-negative int ────────────────────────────────────────────────────


def validate_nonneg_int(value: Any) -> int:
    """Validate a non-negative integer."""
    v = validate_int(value)
    if v < 0:
        raise ValidationError("nonneg_int", value, "must be >= 0")
    return v


# ── Item de prova (M###, R##, ...) ──────────────────────────────────────

_ITEM_RE = re.compile(r"^[A-Z]{1,4}\d{1,6}$")


def validate_item_id(value: Any) -> str:
    """Validate an item id used by the proof ledgers (prefix + digits, e.g. M193)."""
    v = validate_nonempty(value)
    if not _ITEM_RE.match(v):
        raise ValidationError("item_id", value, "must be prefix+digits (e.g. M193)")
    return v


# ── 0/1 (feito / não feito) ─────────────────────────────────────────────


def validate_zero_or_one(value: Any) -> int:
    """Validate the coverage value: 1 = feito/provado, 0 = não feito."""
    v = validate_int(value)
    if v not in (0, 1):
        raise ValidationError("zero_or_one", value, "must be 0 or 1")
    return v
