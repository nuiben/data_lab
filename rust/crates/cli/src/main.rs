use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(name = "data_lab", about = "data_lab CLI", version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// List objects in the configured S3 bucket under a prefix
    S3List {
        #[arg(short, long, default_value = "")]
        prefix: String,
    },
    /// Show Parquet files exported to S3 by the Python export pipeline
    ExportStatus {
        #[arg(short, long, default_value = "fintech/")]
        prefix: String,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cli = Cli::parse();
    let bucket = std::env::var("DATA_LAB_S3_BUCKET").expect("DATA_LAB_S3_BUCKET must be set");
    let connector = connectors::s3::S3Connector::new(bucket).await?;

    match cli.command {
        Commands::S3List { prefix } => {
            let objects = connector.list_objects(&prefix).await?;
            for obj in objects {
                println!("{}", serde_json::to_string(&obj)?);
            }
        }

        Commands::ExportStatus { prefix } => {
            let objects = connector.list_objects(&prefix).await?;
            if objects.is_empty() {
                println!("No exported files found under prefix: {prefix}");
            } else {
                println!("{:<65} {:>10}", "Key", "Size");
                println!("{}", "-".repeat(77));
                for obj in &objects {
                    let size = obj
                        .size_bytes
                        .map(|b| format!("{:.1} KB", b as f64 / 1024.0))
                        .unwrap_or_else(|| "unknown".into());
                    println!("{:<65} {:>10}", obj.key, size);
                }
                println!("{}", "-".repeat(77));
                println!("{} file(s)", objects.len());
            }
        }
    }

    Ok(())
}
