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
