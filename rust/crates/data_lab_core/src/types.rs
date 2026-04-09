use serde::{Deserialize, Serialize};

/// Represents a staged S3 object reference.
/// Used as a common handoff type between the connectors crate and CLI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct S3ObjectRef {
    pub bucket: String,
    pub key: String,
    pub size_bytes: Option<u64>,
    pub etag: Option<String>,
}

/// Generic record row for lightweight data passing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataRecord {
    pub source: String,
    pub payload: serde_json::Value,
}
