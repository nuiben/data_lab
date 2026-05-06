"""Step Functions connector.

Thin typed wrapper over boto3 SFN so callers don't scatter client construction
or raw JSON serialization across the codebase.
"""

from __future__ import annotations

import json
import os
from typing import TYPE_CHECKING

import boto3
import structlog

if TYPE_CHECKING:
    from mypy_boto3_stepfunctions import SFNClient

log = structlog.get_logger(__name__)


def get_client() -> "SFNClient":
    return boto3.client("stepfunctions", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def start_execution(state_machine_arn: str, name: str, input_data: dict[str, object] | None = None) -> str:
    """Start a state machine execution and return the execution ARN."""
    client = get_client()
    resp = client.start_execution(
        stateMachineArn=state_machine_arn,
        name=name,
        input=json.dumps(input_data or {}),
    )
    execution_arn: str = resp["executionArn"]
    log.info("sfn.start_execution", execution_arn=execution_arn)
    return execution_arn


def get_execution_status(execution_arn: str) -> str:
    """Return the current status string (RUNNING, SUCCEEDED, FAILED, etc.)."""
    client = get_client()
    resp = client.describe_execution(executionArn=execution_arn)
    status: str = resp["status"]
    log.info("sfn.status", execution_arn=execution_arn, status=status)
    return status
