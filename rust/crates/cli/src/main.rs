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
    /// List objects in the configured S3 bucket
    S3List {
        #[arg(short, long, default_value = "")]
        prefix: String,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cli = Cli::parse();

    match cli.command {
        Commands::S3List { prefix } => {
            let bucket =
                std::env::var("DATA_LAB_S3_BUCKET").expect("DATA_LAB_S3_BUCKET must be set");
            let connector = connectors::s3::S3Connector::new(bucket).await?;
            let objects = connector.list_objects(&prefix).await?;
            for obj in objects {
                println!("{}", serde_json::to_string(&obj)?);
            }
        }
    }

    Ok(())
}
