FROM rust:1-slim-bookworm AS build
WORKDIR /src

COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

FROM debian:bookworm-slim AS runtime
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target/release/combat-service /app/combat-service

ENV COMBAT_SERVICE_ADDR=0.0.0.0:8080
EXPOSE 8080
ENTRYPOINT ["/app/combat-service"]
