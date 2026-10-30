"""
ValidatedModelMetaclass — zero-hardcode, validated CRUD foundation (S7).

Every domain class inherits ValidatedModelBase (which uses this metaclass).
The metaclass collects FieldSpecs, enforces the zero-hardcode contract, and
registers the class with DomainFactory. The base class provides __init__,
update, and to_dict as regular methods — no runtime injection, so static type
checkers handle them naturally.
"""

from __future__ import annotations

import enum
import hashlib
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any, NamedTuple

# ── source_policy enum (S7) ──────────────────────────────────────────────


class SourcePolicy(str, enum.Enum):
    """Where a field's value must originate. 'literal' is the only policy that
    permits a hardcoded default, and only when a test asserts it is intentional."""

    ENV = "env"
    CONFIG = "config"
    DB = "db"
    ARG = "arg"
    LITERAL = "literal"


# ── FieldSpec (S7) ───────────────────────────────────────────────────────


@dataclass(frozen=True)
class FieldSpec:
    """Declarative field definition collected by the metaclass at class creation."""

    name: str
    validator: Callable[[Any], Any]
    source_policy: SourcePolicy
    required: bool = True
    default: Any = None  # only allowed when source_policy == LITERAL

    def __post_init__(self) -> None:
        if not callable(self.validator):
            raise MetaclassError(f"FieldSpec '{self.name}': validator must be callable")
        if not isinstance(self.source_policy, SourcePolicy):
            raise MetaclassError(
                f"FieldSpec '{self.name}': source_policy must be a SourcePolicy, "
                f"got {type(self.source_policy)}"
            )
        if self.default is not None and self.source_policy is not SourcePolicy.LITERAL:
            raise MetaclassError(
                f"FieldSpec '{self.name}': hardcoded default is forbidden for "
                f"source_policy={self.source_policy.value} (only LITERAL allows defaults)"
            )


# ── Exceptions ───────────────────────────────────────────────────────────


class MetaclassError(TypeError):
    """Class definition violated the zero-hardcode / validated contract."""


class ValidationError(ValueError):
    """A field value failed its validator at construction or update time."""

    def __init__(self, field_name: str, value: Any, detail: str) -> None:
        self.field_name = field_name
        self.value = value
        self.detail = detail
        super().__init__(f"[{field_name}] {detail} (got: {value!r})")


# ── Result of a validation pass ───────────────────────────────────────────


class ValidationOutcome(NamedTuple):
    field_name: str
    original: Any
    validated: Any
    source_policy: str


# ── Factory registry (populated by the metaclass at class creation) ──────


_FACTORY_REGISTRY: dict[str, type] = {}


def _register_with_factory(cls: type) -> None:
    """Called by the metaclass for every domain class."""
    kind = getattr(cls, "_kind_", None)
    if kind is None:
        return  # abstract base — not creatable via factory
    if not isinstance(kind, str) or not kind:
        raise MetaclassError(f"{cls.__name__}: _kind_ must be a non-empty string")
    if kind in _FACTORY_REGISTRY and _FACTORY_REGISTRY[kind] is not cls:
        raise MetaclassError(
            f"{cls.__name__}: _kind_='{kind}' already registered to "
            f"{_FACTORY_REGISTRY[kind].__name__}"
        )
    _FACTORY_REGISTRY[kind] = cls


# ── ValidatedModelMetaclass (S7) ─────────────────────────────────────────


class ValidatedModelMetaclass(type):
    """
    Metaclass that enforces the zero-hardcode, validated-CRUD contract (S7).

    Collects FieldSpecs from the class and its bases, rejects non-LITERAL
    fields with hardcoded defaults, and registers the class with DomainFactory.
    Methods (__init__, update, to_dict) are defined on ValidatedModelBase, not
    injected — so static type checkers handle them naturally.
    """

    def __new__(
        mcs, name: str, bases: tuple, namespace: dict, **kwargs: Any
    ) -> ValidatedModelMetaclass:  # type: ignore[misc]
        # collect inherited _fields_ (subclasses extend, not replace)
        inherited: list[FieldSpec] = []
        for base in bases:
            inherited.extend(getattr(base, "_field_specs_", []))

        own_fields: list[FieldSpec] = list(namespace.get("_fields_", []))
        seen_names: set[str] = {f.name for f in inherited}
        for fs in own_fields:
            if fs.name in seen_names:
                raise MetaclassError(f"{name}: field '{fs.name}' shadows an inherited field")
            seen_names.add(fs.name)

        all_fields = inherited + own_fields

        # enforce zero-hardcode contract on the class definition
        for fs in all_fields:
            if fs.default is not None and fs.source_policy is not SourcePolicy.LITERAL:
                raise MetaclassError(
                    f"{name}: field '{fs.name}' has a hardcoded default but "
                    f"source_policy={fs.source_policy.value} — forbidden "
                    f"(only LITERAL allows defaults)"
                )

        namespace["_field_specs_"] = all_fields
        cls = super().__new__(mcs, name, bases, namespace)
        _register_with_factory(cls)
        return cls


# ── ValidatedModelBase — provides __init__, update, to_dict (S7) ─────────


class ValidatedModelBase(metaclass=ValidatedModelMetaclass):
    """
    Base class for all domain objects. Provides validated __init__, update,
    and to_dict using the _field_specs_ collected by the metaclass.

    Subclasses define _kind_ and _fields_:
        class Run(ValidatedModelBase):
            _kind_ = "run"
            _fields_ = [FieldSpec("id", validate_uuid, SourcePolicy.ARG), ...]
    """

    _field_specs_: list[FieldSpec] = []  # noqa: RUF012

    def __init__(self, **kwargs: Any) -> None:
        specs_by_name = {fs.name: fs for fs in self._field_specs_}
        self._values = {}  # dict[str, Any]
        for fs in self._field_specs_:
            if fs.name in kwargs:
                self._values[fs.name] = self._validate_field(fs, kwargs[fs.name])
            elif fs.default is not None and fs.source_policy is SourcePolicy.LITERAL:
                self._values[fs.name] = self._validate_field(fs, fs.default)
            elif fs.required:
                raise ValidationError(
                    fs.name,
                    None,
                    f"required field missing (source_policy={fs.source_policy.value})",
                )
            else:
                self._values[fs.name] = None
        unknown = set(kwargs) - set(specs_by_name)
        if unknown:
            raise ValidationError(
                next(iter(unknown)),
                None,
                f"unknown field(s); valid fields: {sorted(specs_by_name)}",
            )

    def update(self, **kwargs: Any) -> ValidatedModelBase:
        specs_by_name = {fs.name: fs for fs in self._field_specs_}
        unknown = set(kwargs) - set(specs_by_name)
        if unknown:
            raise ValidationError(
                next(iter(unknown)),
                None,
                f"unknown field(s); valid fields: {sorted(specs_by_name)}",
            )
        # validate ALL proposed changes FIRST; do not mutate until all pass
        proposed: dict[str, Any] = {}
        for fname, raw in kwargs.items():
            fs = specs_by_name[fname]
            proposed[fname] = self._validate_field(fs, raw)
        self._values.update(proposed)
        return self

    def to_dict(self) -> dict[str, Any]:
        return dict(self._values)

    @staticmethod
    def _validate_field(fs: FieldSpec, raw: Any) -> Any:
        try:
            return fs.validator(raw)
        except ValidationError:
            raise
        except Exception as exc:
            raise ValidationError(fs.name, raw, f"validator raised: {exc}") from exc


# ── evidence hashing helper (S3) ─────────────────────────────────────────


def evidence_hash(command: str, stdout: str, stderr: str, exit_code: int) -> str:
    """SHA-256 over (command, stdout, stderr, exit_code). Provenance anchor for
    every objective/transition/risk — an answer that cites a hash is grounded."""
    payload = f"\x00{command}\x00{stdout}\x00{stderr}\x00{exit_code}\x00".encode()
    return hashlib.sha256(payload).hexdigest()


# ── common validators (pure functions, no hardcoded literals) ────────────


def validate_nonempty(value: Any) -> str:
    if not isinstance(value, str):
        raise ValidationError("(nonempty)", value, "must be a string")
    if not value.strip():
        raise ValidationError("(nonempty)", value, "must be non-empty")
    return value


def validate_optional_str(value: Any) -> str | None:
    """Accept None or any string (including empty). Rejects non-strings."""
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValidationError("(optional_str)", value, "must be a string or None")
    return value


def validate_int(value: Any) -> int:
    if isinstance(value, bool):
        raise ValidationError("(int)", value, "bool is not int")
    if not isinstance(value, int):
        raise ValidationError("(int)", value, "must be an int")
    return value


def validate_exit_code(value: Any) -> int:
    v = validate_int(value)
    if not (0 <= v <= 255):
        raise ValidationError("(exit_code)", value, "must be 0..255")
    return v


def validate_bool(value: Any) -> bool:
    if not isinstance(value, bool):
        raise ValidationError("(bool)", value, "must be a bool")
    return value


def validate_enum_factory(enum_cls: type[enum.Enum]) -> Callable[[Any], enum.Enum]:
    """Return a validator that accepts the enum or its value string."""

    def _validate(value: Any) -> enum.Enum:
        if isinstance(value, enum_cls):
            return value
        if isinstance(value, str):
            for member in enum_cls:
                if member.value == value or member.name == value:
                    return member
        raise ValidationError(
            f"({enum_cls.__name__})",
            value,
            f"must be one of {[m.value for m in enum_cls]}",
        )

    return _validate
