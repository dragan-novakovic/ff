mod domain;

use axum::{
    extract::Path,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use domain::{CombatMission, FightRequest, FightResponse};
use serde::Serialize;
use std::{env, net::SocketAddr};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = env::var("COMBAT_SERVICE_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
        .parse::<SocketAddr>()?;
    let listener = tokio::net::TcpListener::bind(addr).await?;

    println!("combat-service listening on {}", listener.local_addr()?);
    axum::serve(listener, app()).await?;

    Ok(())
}

fn app() -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/missions", get(missions))
        .route("/missions/:mission_id", get(mission))
        .route("/simulate/fight", post(simulate_fight))
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "combat-service",
    })
}

async fn simulate_fight(
    Json(request): Json<FightRequest>,
) -> Result<Json<FightResponse>, ApiError> {
    domain::simulate_fight(request).map(Json).map_err(ApiError)
}

async fn missions() -> Json<Vec<CombatMission>> {
    Json(domain::missions())
}

async fn mission(Path(mission_id): Path<String>) -> Result<Json<CombatMission>, MissionError> {
    domain::find_mission(&mission_id).map(Json).ok_or(MissionError)
}

#[derive(Debug)]
struct ApiError(domain::FightError);

#[derive(Debug)]
struct MissionError;

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let body = Json(ErrorResponse {
            error: self.0.to_string(),
        });

        (StatusCode::BAD_REQUEST, body).into_response()
    }
}

impl IntoResponse for MissionError {
    fn into_response(self) -> Response {
        let body = Json(ErrorResponse {
            error: "mission was not found".to_string(),
        });

        (StatusCode::NOT_FOUND, body).into_response()
    }
}
