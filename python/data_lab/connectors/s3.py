"""S3 connector using boto3.

Intentionally thin — provides typed helpers over raw boto3 calls
so the rest of the codebase doesn't scatter client construction logic.
"""

from __future__ import annotations

import os
from typing import Iterator

import boto3
import structlog

log = structlog.get_logger(__name__)


def get_client() -> boto3.client:
    """Return a boto3 S3 client, picking up credentials from the environment."""
    return boto3.client("s3", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def list_objects(bucket: str, prefix: str = "") -> Iterator[dict]:
    """Yield object metadata dicts for every key under *prefix*."""
    client = get_client()
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            log.debug("s3.list_objects", bucket=bucket, key=obj["Key"])
            yield obj


def upload_file(local_path: str, bucket: str, key: str) -> None:
    client = get_client()
    client.upload_file(local_path, bucket, key)
    log.info("s3.upload", bucket=bucket, key=key)


def download_file(bucket: str, key: str, local_path: str) -> None:
    client = get_client()
    client.download_file(bucket, key, local_path)
    log.info("s3.download", bucket=bucket, key=key, dest=local_path)
