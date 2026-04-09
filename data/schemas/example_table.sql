-- Example staging table in Snowflake
-- Run via: snowflake.execute_query(open("data/schemas/example_table.sql").read())

CREATE TABLE IF NOT EXISTS DATA_LAB.PUBLIC.EXAMPLE_EVENTS (
    event_id      VARCHAR(36)   NOT NULL,
    source        VARCHAR(128)  NOT NULL,
    event_type    VARCHAR(64)   NOT NULL,
    payload       VARIANT,                   -- Snowflake semi-structured column
    ingested_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    s3_key        VARCHAR(512),              -- back-reference to raw S3 object

    CONSTRAINT pk_example_events PRIMARY KEY (event_id)
);

COMMENT ON TABLE DATA_LAB.PUBLIC.EXAMPLE_EVENTS IS
    'Staging table for raw events ingested from S3 via Lambda.';
