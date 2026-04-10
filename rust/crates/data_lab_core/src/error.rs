use thiserror::Error;

#[derive(Debug, Error)]
pub enum DataLabError {
    #[error("S3 error: {0}")]
    S3(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serde(#[from] serde_json::Error),

    #[error("Unexpected error: {0}")]
    Other(#[from] anyhow::Error),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn s3_error_display() {
        let e = DataLabError::S3("bucket not found".into());
        assert_eq!(e.to_string(), "S3 error: bucket not found");
    }

    #[test]
    fn config_error_display() {
        let e = DataLabError::Config("missing AWS_REGION".into());
        assert_eq!(e.to_string(), "Configuration error: missing AWS_REGION");
    }

    #[test]
    fn io_error_converts() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file missing");
        let e: DataLabError = io_err.into();
        assert!(e.to_string().contains("IO error"));
    }

    #[test]
    fn serde_error_converts() {
        let serde_err = serde_json::from_str::<serde_json::Value>("not json").unwrap_err();
        let e: DataLabError = serde_err.into();
        assert!(e.to_string().contains("Serialization error"));
    }
}
