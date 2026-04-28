use anyhow::Result;
use aws_sdk_s3::{primitives::ByteStream, Client};
use data_lab_core::types::S3ObjectRef;
use tracing::info;

pub struct S3Connector {
    client: Client,
    bucket: String,
}

impl S3Connector {
    pub async fn new(bucket: impl Into<String>) -> Result<Self> {
        let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
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

        let refs: Vec<S3ObjectRef> = resp
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

    /// Upload raw bytes to *key* with the given content type.
    pub async fn upload_bytes(&self, key: &str, data: Vec<u8>, content_type: &str) -> Result<()> {
        let size = data.len();
        self.client
            .put_object()
            .bucket(&self.bucket)
            .key(key)
            .content_type(content_type)
            .content_length(size as i64)
            .body(ByteStream::from(data))
            .send()
            .await?;
        info!(bucket = %self.bucket, key = key, bytes = size, "Uploaded bytes to S3");
        Ok(())
    }

    /// Upload a local file to *key*. Content type is inferred from the extension.
    pub async fn upload_file(
        &self,
        path: impl AsRef<std::path::Path>,
        key: &str,
    ) -> Result<()> {
        let path = path.as_ref();
        let data = tokio::fs::read(path).await?;
        let content_type = match path.extension().and_then(|e| e.to_str()) {
            Some("parquet") => "application/octet-stream",
            Some("json")    => "application/json",
            Some("csv")     => "text/csv",
            _               => "application/octet-stream",
        };
        self.upload_bytes(key, data, content_type).await
    }
}
