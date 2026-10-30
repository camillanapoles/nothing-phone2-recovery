"""
DomainFactory — single entrypoint for CRUD creation (S7).

The factory reads `_FACTORY_REGISTRY` which is populated automatically by
`ValidatedModelMetaclass` at class creation time. No manual register() calls,
no hardcoded kind strings outside the class.

    Run.objects = DomainFactory("run", name="...", device_serial="...")

Both create() and update() run the metaclass-injected validators; a rejected
value leaves the object unchanged.
"""

from __future__ import annotations

from typing import Any

from .metaclass import (
    _FACTORY_REGISTRY,
    ValidationError,
)


class DomainFactory:
    """Lookup-by-kind dispatcher over the metaclass registry."""

    @staticmethod
    def create(kind: str, **kwargs: Any) -> Any:
        """Instantiate a domain object of the given kind. Runs all validators."""
        if kind not in _FACTORY_REGISTRY:
            raise ValidationError(
                "(factory)",
                kind,
                f"unknown domain kind; registered: {sorted(_FACTORY_REGISTRY)}",
            )
        cls = _FACTORY_REGISTRY[kind]
        return cls(**kwargs)

    @staticmethod
    def update(obj: Any, **kwargs: Any) -> Any:
        """Update an existing domain object in place. Runs validators; atomic on
        rejection (the "update garantido" contract — object unchanged on error)."""
        return obj.update(**kwargs)

    @staticmethod
    def registered_kinds() -> list[str]:
        """Return all domain kinds registered by the metaclass."""
        return sorted(_FACTORY_REGISTRY)

    @staticmethod
    def class_for(kind: str) -> type:
        """Return the class registered for a kind (for schema introspection)."""
        if kind not in _FACTORY_REGISTRY:
            raise ValidationError(
                "(factory)",
                kind,
                f"unknown domain kind; registered: {sorted(_FACTORY_REGISTRY)}",
            )
        return _FACTORY_REGISTRY[kind]

    @staticmethod
    def field_specs_for(kind: str) -> list:
        """Return the FieldSpec list for a kind (for schema generation / API docs)."""
        return DomainFactory.class_for(kind)._field_specs_  # type: ignore[attr-defined]
