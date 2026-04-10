"""Tests for structured logging configuration."""

import pytest

from data_lab.utils.logging import configure_logging


def test_configure_logging_runs() -> None:
    configure_logging()


def test_configure_logging_idempotent() -> None:
    configure_logging()
    configure_logging()


def test_log_level_respects_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    configure_logging()


def test_log_level_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LOG_LEVEL", raising=False)
    configure_logging()
