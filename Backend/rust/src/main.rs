use face_payment_backend::{initialize, Config};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Explicit process variables take precedence over the ignored local file.
    if let Err(error) = dotenvy::dotenv() {
        if !error.not_found() {
            return Err("Could not load .env; check its syntax without sharing secrets.".into());
        }
    }
    let config = Config::from_env()?;
    let bind = config.bind_addr;
    // Database identity is checked before any migration or HTTP listener starts.
    let app = initialize(config).await?;
    let listener = tokio::net::TcpListener::bind(bind).await?;
    println!("FacePay authentication API listening on http://{bind}");
    println!("No SMS delivery is configured.");
    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await?;
    Ok(())
}
