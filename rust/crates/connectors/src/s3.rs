use anyhow::Result;
use aws_sdk_s3::Client;
use data_lab_core::types::S3ObjectRef;
use tracing::info;

pub struct S3Connector {
    client: Client,
    bucket: String,
}

impl S3Connector {
    pub async fn new(bucket: impl Into<String>) -> Result<Self> {
        let config = aws_config::load_from_env().await;
        let client = Client::new(&config);
        Ok(Self {
            client,
            bucket: bucket.into(),
        })
    }

    /// List objects under a key prefix. Returns lightweight refs.
    pub async fn list_objects(&self, prefix: &str) -> Result<Vec<S3ObjectRef>> {
        let resp = self
            .client
            .list_objects_v2()
            .bucket(&self.bucket)
            .prefix(prefix)
            .send()
            .await?;

        let refs = resp
            .contents()
            .iter()
            .map(|obj| S3ObjectRef {
                bucket: self.bucket.clone(),
                key: obj.key().unwrap_or_default().to_string(),
                size_bytes: obj.size().map(|s| s as u64),
                etag: obj.e_tag().map(|e| e.to_string()),
            })
            .collect();

        info!(bucket = %self.bucket, prefix = prefix, count = refs.len(), "Listed S3 objects");
        Ok(refs)
    }
}
