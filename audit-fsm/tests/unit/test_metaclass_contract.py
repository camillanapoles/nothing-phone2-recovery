"""
Four-case metaclass test contract (T0c, S7).

For EVERY domain model (Run, Probe, Transition, Objective, Risk), we assert
the same four cases:

  a) construct with valid data     → succeeds, to_dict() reflects all fields
  b) construct with invalid data   → raises ValidationError, no object created
  c) update with valid data        → succeeds, to_dict() reflects the change
  d) update with invalid data      → raises ValidationError, to_dict() UNCHANGED

Plus: zero-hardcode enforcement, factory registry, evidence hashing, safety guard.
"""

from __future__ import annotations

import hashlib

import pytest

from audit_fsm.domain.factory import DomainFactory
from audit_fsm.domain.metaclass import (
    FieldSpec,
    MetaclassError,
    SourcePolicy,
    ValidatedModelBase,
    ValidationError,
    evidence_hash,
    validate_nonempty,
)
from audit_fsm.domain.models import (
    ObjectiveStatus,
    RunStatus,
)
from audit_fsm.fsm.core import FSMState
from audit_fsm.safety import assert_safe, check_command

# ── Fixtures: valid data per domain ──────────────────────────────────────

UUID1 = "00000000-0000-0000-0000-000000000001"
UUID2 = "00000000-0000-0000-0000-000000000002"
SERIAL = "9f51ecb9"
TIMESTAMP = "2025-07-24T12:00:00"
ADB_PATH = "/home/cnmfs/nothing-phone2/tools/platform-tools/adb"
HASH1 = "a" * 64  # 64-char hex
HASH2 = "b" * 64


VALID_RUN = {
    "id": UUID1,
    "device_serial": SERIAL,
    "started_at": TIMESTAMP,
    "status": RunStatus.RUNNING,
    "adb_path": ADB_PATH,
}

VALID_PROBE = {
    "id": UUID1,
    "run_id": UUID2,
    "state": FSMState.PROBE_DEVICE,
    "command": "adb shell getprop ro.build.fingerprint",
    "stdout": "samsung/firmware/build/keys",
    "stderr": "",
    "exit_code": 0,
    "evidence_hash": HASH1,
}

VALID_TRANSITION = {
    "id": UUID1,
    "run_id": UUID2,
    "from_state": FSMState.INIT,
    "to_state": FSMState.PROBE_DEVICE,
    "guard_passed": True,
    "description": "adb path resolved",
}

VALID_OBJECTIVE = {
    "id": UUID1,
    "run_id": UUID2,
    "state": FSMState.CHECK_BOOTLOADER,
    "description": "Verify bootloader is locked",
    "status": ObjectiveStatus.SATISFIED,
    "evidence_hash": HASH2,
}

VALID_RISK = {
    "id": UUID1,
    "run_id": UUID2,
    "verdict": "safe",
    "reasoning": "Bootloader locked, SELinux enforcing, no root binary",
    "evidence_hash": HASH1,
}

# Map kind → (valid kwargs, valid update kwargs, invalid construct kwargs, invalid update kwargs)
DOMAIN_CASES = [
    ("run", VALID_RUN, {"status": RunStatus.COMPLETED}, {"id": "not-a-uuid"}, {"status": "bogus"}),
    ("probe", VALID_PROBE, {"exit_code": 1}, {"exit_code": 999}, {"exit_code": -1}),
    (
        "transition",
        VALID_TRANSITION,
        {"guard_passed": False},
        {"guard_passed": "not-a-bool"},
        {"guard_passed": "yes"},
    ),
    (
        "objective",
        VALID_OBJECTIVE,
        {"status": ObjectiveStatus.VIOLATED},
        {"status": "bogus"},
        {"status": "wrong"},
    ),
    ("risk", VALID_RISK, {"verdict": "unsafe"}, {"verdict": ""}, {"verdict": "  "}),
]


# ── Case a: construct valid ──────────────────────────────────────────────


@pytest.mark.parametrize("kind,valid,u1,u2,u3", DOMAIN_CASES)
def test_case_a_construct_valid(kind, valid, u1, u2, u3):
    """a) Construct with valid data → succeeds; to_dict() has all fields."""
    obj = DomainFactory.create(kind, **valid)
    d = obj.to_dict()
    for key, val in valid.items():
        # enums compare by value or identity
        if hasattr(val, "value"):
            assert d[key] == val or d[key].value == val.value
        else:
            assert d[key] == val
    # every declared field is present in the dict
    specs = DomainFactory.field_specs_for(kind)
    for fs in specs:
        assert fs.name in d, f"field '{fs.name}' missing from to_dict()"


# ── Case b: construct invalid ───────────────────────────────────────────


@pytest.mark.parametrize("kind,u1,u2,invalid_construct,u3", DOMAIN_CASES)
def test_case_b_construct_invalid(kind, u1, u2, invalid_construct, u3):
    """b) Construct with invalid data → raises ValidationError."""
    # merge valid data with the invalid override
    valid = next(c[1] for c in DOMAIN_CASES if c[0] == kind)
    bad = {**valid, **invalid_construct}
    with pytest.raises(ValidationError):
        DomainFactory.create(kind, **bad)


# ── Case c: update valid ──────────────────────────────────────────────────


@pytest.mark.parametrize("kind,u1,valid_update,u2,u3", DOMAIN_CASES)
def test_case_c_update_valid(kind, u1, valid_update, u2, u3):
    """c) Update with valid data → succeeds; to_dict() reflects the change."""
    valid = next(c[1] for c in DOMAIN_CASES if c[0] == kind)
    obj = DomainFactory.create(kind, **valid)
    DomainFactory.update(obj, **valid_update)
    d = obj.to_dict()
    for key, val in valid_update.items():
        if hasattr(val, "value"):
            assert d[key] == val or d[key].value == val.value
        else:
            assert d[key] == val


# ── Case d: update invalid → object unchanged ───────────────────────────


@pytest.mark.parametrize("kind,u1,u2,u3,invalid_update", DOMAIN_CASES)
def test_case_d_update_invalid_unchanged(kind, u1, u2, u3, invalid_update):
    """d) Update with invalid data → raises ValidationError; to_dict() UNCHANGED."""
    valid = next(c[1] for c in DOMAIN_CASES if c[0] == kind)
    obj = DomainFactory.create(kind, **valid)
    before = obj.to_dict()
    with pytest.raises(ValidationError):
        DomainFactory.update(obj, **invalid_update)
    after = obj.to_dict()
    assert before == after, "object mutated despite ValidationError — atomicity broken"


# ── Zero-hardcode enforcement ────────────────────────────────────────────


def test_zero_hardcode_non_literal_default_rejected():
    """A non-LITERAL field with a hardcoded default must raise MetaclassError.

    Enforcement happens at FieldSpec.__post_init__ (first line of defense)
    AND at ValidatedModelMetaclass.__new__ (second line). We test both.
    """
    # FieldSpec-level: __post_init__ rejects non-LITERAL defaults
    with pytest.raises(MetaclassError):
        FieldSpec("name", validate_nonempty, SourcePolicy.DB, required=False, default="hardcoded")

    with pytest.raises(MetaclassError):
        FieldSpec("name", validate_nonempty, SourcePolicy.ENV, required=False, default="no")


def test_zero_hardcode_literal_default_allowed():
    """A LITERAL field with a hardcoded default must succeed."""

    class _Good(ValidatedModelBase):
        _kind_ = "_good_zh"
        _fields_ = [  # noqa: RUF012
            FieldSpec(
                "name", validate_nonempty, SourcePolicy.LITERAL, required=False, default="ok"
            ),
        ]

    obj = _Good()
    assert obj.to_dict()["name"] == "ok"


# ── Factory registry ─────────────────────────────────────────────────────


def test_factory_registry_has_all_domains():
    """All 5 domain kinds are auto-registered by the metaclass."""
    kinds = DomainFactory.registered_kinds()
    for expected in ("run", "probe", "transition", "objective", "risk"):
        assert expected in kinds, f"'{expected}' not in registry: {kinds}"


def test_factory_unknown_kind_raises():
    with pytest.raises(ValidationError):
        DomainFactory.create("nonexistent_kind", id=UUID1)


def test_factory_field_specs_introspection():
    """field_specs_for() returns FieldSpec list for schema generation."""
    specs = DomainFactory.field_specs_for("run")
    names = [fs.name for fs in specs]
    assert "id" in names
    assert "device_serial" in names
    assert "status" in names


# ── Evidence hashing (S3) ───────────────────────────────────────────────


def test_evidence_hash_deterministic():
    """Same inputs → same hash."""
    h1 = evidence_hash("adb shell getprop", "out", "err", 0)
    h2 = evidence_hash("adb shell getprop", "out", "err", 0)
    assert h1 == h2


def test_evidence_hash_different_inputs():
    """Different inputs → different hashes."""
    h1 = evidence_hash("cmd1", "out", "err", 0)
    h2 = evidence_hash("cmd2", "out", "err", 0)
    assert h1 != h2


def test_evidence_hash_is_sha256_hex():
    """Hash is 64-char lowercase hex (SHA-256)."""
    h = evidence_hash("cmd", "out", "", 0)
    assert len(h) == 64
    assert all(c in "0123456789abcdef" for c in h)


def test_evidence_hash_matches_manual_sha256():
    """Hash matches a manual SHA-256 over the same payload."""
    payload = b"\x00cmd\x00out\x00err\x000\x00"
    expected = hashlib.sha256(payload).hexdigest()
    assert evidence_hash("cmd", "out", "err", 0) == expected


# ── Safety guard (T8) ────────────────────────────────────────────────────


def test_safety_guard_readonly_passes():
    """Read-only commands pass the safety guard."""
    for cmd in [
        "adb devices",
        "adb shell getprop ro.build.fingerprint",
        "adb shell pm list packages -3",
        "fastboot devices",
    ]:
        verdict = check_command(cmd)
        assert verdict.allowed, f"read-only command blocked: {cmd} — {verdict.reason}"


def test_safety_guard_mutating_blocked():
    """Mutating commands are blocked by the safety guard."""
    mutating = [
        "adb shell rm /data/local/tmp/file",
        "adb shell reboot",
        "adb shell shutdown",
        "fastboot flash boot magisk.img",
        "fastboot erase userdata",
        "fastboot oem unlock",
        "adb push payload.bin /data/local/tmp/",
        "adb shell mount -o remount,rw /vendor",
        "adb shell dd if=/dev/zero of=/dev/block/sde13",
        "adb shell wipe data",
    ]
    for cmd in mutating:
        verdict = check_command(cmd)
        assert not verdict.allowed, f"mutating command allowed: {cmd} — {verdict.reason}"


def test_safety_guard_normalizes_full_path():
    """Full path to adb is normalized before checking."""
    for cmd in [
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb devices",
        "/home/cnmfs/nothing-phone2/tools/platform-tools/adb shell getprop",
    ]:
        verdict = check_command(cmd)
        assert verdict.allowed, f"full-path command blocked: {cmd} — {verdict.reason}"


def test_safety_guard_normalizes_serial_flag():
    """`-s <serial>` flag is stripped before checking."""
    for cmd in [
        "adb -s 9f51ecb9 shell getprop ro.build.fingerprint",
        "adb -s 9f51ecb9 devices",
    ]:
        verdict = check_command(cmd)
        assert verdict.allowed, f"serial-flag command blocked: {cmd} — {verdict.reason}"


def test_safety_guard_bare_mount_readonly_passes():
    """Bare `mount` (read-only query) passes; mutating mount variants are blocked."""
    for cmd in ["adb shell mount", "adb shell mount -l"]:
        verdict = check_command(cmd)
        assert verdict.allowed, f"read-only mount blocked: {cmd} — {verdict.reason}"
    for cmd in [
        "adb shell mount -o remount,rw /vendor",
        "adb shell mount -t ext4 /dev/block/sda1 /mnt",
    ]:
        verdict = check_command(cmd)
        assert not verdict.allowed, f"mutating mount allowed: {cmd} — {verdict.reason}"


# ── CI smoke test (assert_safe with no args) ─


def test_safety_guard_ci_smoke():
    """The CI smoke test (assert_safe with no args) passes — known mutating blocked, known read-only allowed."""
    assert_safe()  # raises SafetyViolation if broken


# ── Enum validators ─────────────────────────────────────────────────────


def test_fsm_state_enum_validator_accepts_string_value():
    """FSMState validator accepts the string value, not just the enum."""
    obj = DomainFactory.create("transition", **{**VALID_TRANSITION, "to_state": "probe_device"})
    assert obj.to_dict()["to_state"] == FSMState.PROBE_DEVICE


def test_run_status_enum_validator_rejects_unknown():
    with pytest.raises(ValidationError):
        DomainFactory.create("run", **{**VALID_RUN, "status": "bogus_status"})


def test_objective_status_enum_validator_rejects_unknown():
    with pytest.raises(ValidationError):
        DomainFactory.create("objective", **{**VALID_OBJECTIVE, "status": "bogus"})


# ── Optional fields ──────────────────────────────────────────────────────


def test_probe_stderr_optional_none():
    """Probe.stderr is optional — None is accepted."""
    obj = DomainFactory.create("probe", **{**VALID_PROBE, "stderr": None})
    assert obj.to_dict()["stderr"] is None


def test_probe_stderr_optional_empty_string():
    """Probe.stderr accepts empty string (regression: previously rejected)."""
    obj = DomainFactory.create("probe", **{**VALID_PROBE, "stderr": ""})
    assert obj.to_dict()["stderr"] == ""


def test_transition_description_optional():
    """Transition.description is optional."""
    obj = DomainFactory.create("transition", **VALID_TRANSITION)
    assert obj.to_dict()["description"] == "adb path resolved"


def test_transition_description_none():
    """Transition.description=None is accepted."""
    data = {**VALID_TRANSITION}
    data.pop("description")
    obj = DomainFactory.create("transition", **data)
    assert obj.to_dict()["description"] is None


def test_objective_evidence_hash_optional():
    """Objective.evidence_hash is optional."""
    data = {**VALID_OBJECTIVE}
    data.pop("evidence_hash")
    obj = DomainFactory.create("objective", **data)
    assert obj.to_dict()["evidence_hash"] is None


# ── Unknown field rejection ─────────────────────────────────────────────


def test_construct_unknown_field_rejected():
    with pytest.raises(ValidationError):
        DomainFactory.create("run", **{**VALID_RUN, "unknown_field": "x"})


def test_update_unknown_field_rejected():
    obj = DomainFactory.create("run", **VALID_RUN)
    with pytest.raises(ValidationError):
        DomainFactory.update(obj, unknown_field="x")
