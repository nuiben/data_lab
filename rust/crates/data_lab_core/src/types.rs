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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn s3_object_ref_roundtrip() {
        let obj = S3ObjectRef {
            bucket: "my-bucket".into(),
            key: "data/foo.parquet".into(),
            size_bytes: Some(1024),
            etag: Some("abc123".into()),
        };
        let serialized = serde_json::to_string(&obj).unwrap();
        let obj2: S3ObjectRef = serde_json::from_str(&serialized).unwrap();
        assert_eq!(obj.bucket, obj2.bucket);
        assert_eq!(obj.key, obj2.key);
        assert_eq!(obj.size_bytes, obj2.size_bytes);
        assert_eq!(obj.etag, obj2.etag);
    }

    #[test]
    fn s3_object_ref_optional_fields_none() {
        let obj = S3ObjectRef {
            bucket: "b".into(),
            key: "k".into(),
            size_bytes: None,
            etag: None,
        };
        let serialized = serde_json::to_string(&obj).unwrap();
        let obj2: S3ObjectRef = serde_json::from_str(&serialized).unwrap();
        assert!(obj2.size_bytes.is_none());
        assert!(obj2.etag.is_none());
    }

    #[test]
    fn data_record_roundtrip() {
        let rec = DataRecord {
            source: "s3".into(),
            payload: json!({"key": "value", "count": 42}),
        };
        let serialized = serde_json::to_string(&rec).unwrap();
        let rec2: DataRecord = serde_json::from_str(&serialized).unwrap();
        assert_eq!(rec.source, rec2.source);
        assert_eq!(rec2.payload["count"], 42);
        assert_eq!(rec2.payload["key"], "value");
    }

    #[test]
    fn s3_object_ref_clone() {
        let obj = S3ObjectRef {
            bucket: "b".into(),
            key: "k".into(),
            size_bytes: Some(512),
            etag: None,
        };
        let cloned = obj.clone();
        assert_eq!(obj.bucket, cloned.bucket);
        assert_eq!(obj.size_bytes, cloned.size_bytes);
    }
}
