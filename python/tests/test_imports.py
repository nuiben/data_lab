"""Smoke tests: verify the package and all submodules import cleanly."""


def test_package_importable() -> None:
    import data_lab

    assert data_lab is not None


def test_utils_logging_importable() -> None:
    from data_lab.utils import logging as dl_logging

    assert callable(dl_logging.configure_logging)


def test_connectors_s3_importable() -> None:
    from data_lab.connectors import s3

    assert callable(s3.get_client)
    assert callable(s3.list_objects)
    assert callable(s3.upload_file)
    assert callable(s3.download_file)


def test_connectors_snowflake_importable() -> None:
    from data_lab.connectors import snowflake

    assert callable(snowflake.get_connection)
    assert callable(snowflake.execute_query)
