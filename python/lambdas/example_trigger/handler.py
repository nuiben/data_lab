"""Example EventBridge-triggered Lambda.

Trigger: EventBridge schedule (see infra/modules/lambda/main.tf)
Purpose: Scaffold showing how to wire up boto3, env vars, and logging
         in a Lambda that will eventually drive a pipeline step.
"""

from __future__ import annotations

import json
import os

import boto3
import structlog

log = structlog.get_logger(__name__)


def handler(event: dict, context: object) -> dict:
    """Lambda entry point."""
    log.info("lambda.invoked", event=event)

    bucket = os.environ.get("DATA_LAB_S3_BUCKET", "")
    if not bucket:
        raise ValueError("DATA_LAB_S3_BUCKET environment variable not set")

    s3 = boto3.client("s3")
    response = s3.list_objects_v2(Bucket=bucket, MaxKeys=5)
    keys = [obj["Key"] for obj in response.get("Contents", [])]

    log.info("lambda.s3_sample", bucket=bucket, keys=keys)

    return {"statusCode": 200, "body": json.dumps({"sampled_keys": keys})}
