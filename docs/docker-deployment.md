---
layout: default
title: Docker Deployment
nav_order: 7
description: "Deploy the full stack using Docker and Docker Compose"
---

# Docker Deployment Guide

This guide explains how to deploy the full Solana starter stack using Docker and Docker Compose.

## Overview

The Docker setup includes:
- **PostgreSQL** - Database for indexer
- **Go Indexer** - Blockchain indexer service
- **Next.js Frontend** - Web application

**Note:** The Solana validator runs on your host machine (localnet) or you can connect to devnet/mainnet.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Running Solana validator (for localnet)
- Deployed Anchor programs

## Quick Start

### 1. Configure Environment

```bash
cp .env.docker .env
```

Edit `.env` with your configuration:
- For **localnet**: Use `http://localhost:8899`
- For **devnet**: Use `https://api.devnet.solana.com`
- For **mainnet**: Use `https://api.mainnet-beta.solana.com`

Update program IDs:
```bash
cd starter_program
anchor keys list

# Copy the program IDs to .env
# NEXT_PUBLIC_STARTER_PROGRAM_ID=<your-starter-program-id>
# NEXT_PUBLIC_COUNTER_PROGRAM_ID=<your-counter-program-id>
```

### 2. Build and Start Services

```bash
docker-compose up -d
```

This will:
1. Start PostgreSQL database
2. Build and start Go indexer
3. Build and start Next.js frontend

### 3. Verify Services

```bash
docker-compose ps

docker-compose logs indexer
docker-compose logs frontend

curl http://localhost:8080/health
curl http://localhost:3000
```

### 4. Access Applications

- **Frontend**: http://localhost:3000
- **Indexer API**: http://localhost:8080
- **PostgreSQL**: localhost:5432

## Docker Compose Services

### PostgreSQL (`postgres`)

Database for storing indexed blockchain data.

**Ports:** 5432
**Volume:** `postgres_data` (persistent storage)
**Health Check:** Automatic with retry

### Go Indexer (`indexer`)

High-performance blockchain indexer.

**Ports:** 8080
**Depends on:** PostgreSQL
**Configuration:** Via environment variables in `.env`

Key environment variables:
- `SOLANA_RPC_URL` - Solana RPC endpoint
- `SOLANA_WS_URL` - Solana WebSocket endpoint
- `DATABASE_URL` - PostgreSQL connection string
- `START_SLOT` - Starting slot for indexing
- `POLL_INTERVAL_MS` - Polling interval
- `BATCH_SIZE` - Blocks per batch
- `MAX_CONCURRENCY` - Concurrent workers

### Next.js Frontend (`frontend`)

Web application for interacting with Anchor programs.

**Ports:** 3000
**Depends on:** Indexer
**Build Args:** Program IDs and network configuration

## Development Workflow

### Building Services

```bash
docker-compose build

docker-compose build indexer

docker-compose build frontend
```

### Starting/Stopping Services

```bash
docker-compose up -d

docker-compose down

docker-compose restart indexer
```

### Viewing Logs

```bash
docker-compose logs -f

docker-compose logs -f indexer

docker-compose logs -f frontend --tail 100
```

### Executing Commands in Containers

```bash
docker-compose exec indexer sh

docker-compose exec postgres psql -U postgres -d solana_indexer
```

## Localnet Development

When developing with localnet, the validator runs on your **host machine**, not in Docker.

### Terminal 1: Start Validator

```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset \
  --quiet
```

### Terminal 2: Deploy Programs

```bash
cd starter_program
solana config set --url localhost
anchor build && anchor deploy
```

### Terminal 3: Start Docker Stack

```bash
docker-compose up -d
docker-compose logs -f
```

The indexer will connect to `host.docker.internal:8899` to reach your local validator.

## Production Deployment

### Devnet

```bash
cp .env.docker .env

# Edit .env
SOLANA_RPC_URL=https://api.devnet.solana.com
SOLANA_WS_URL=wss://api.devnet.solana.com
NEXT_PUBLIC_SOLANA_RPC_HOST=https://api.devnet.solana.com
NEXT_PUBLIC_SOLANA_NETWORK=devnet
START_SLOT=latest
POLL_INTERVAL_MS=5000

docker-compose up -d
```

### Mainnet-Beta

```bash
cp .env.docker .env

# Edit .env
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
SOLANA_WS_URL=wss://api.mainnet-beta.solana.com
NEXT_PUBLIC_SOLANA_RPC_HOST=https://api.mainnet-beta.solana.com
NEXT_PUBLIC_SOLANA_NETWORK=mainnet-beta
START_SLOT=latest
POLL_INTERVAL_MS=10000
BATCH_SIZE=5

docker-compose up -d
```

**Note:** For production, consider using:
- Dedicated RPC providers (QuickNode, Alchemy, Helius)
- Nginx reverse proxy
- SSL/TLS certificates
- Environment-specific .env files
- Health monitoring
- Log aggregation

## Database Management

### Connect to PostgreSQL

```bash
docker-compose exec postgres psql -U postgres -d solana_indexer
```

### Run Migrations

```bash
docker-compose exec indexer sh -c "go run migrations/*.go"
```

### Backup Database

```bash
docker-compose exec postgres pg_dump -U postgres solana_indexer > backup.sql
```

### Restore Database

```bash
cat backup.sql | docker-compose exec -T postgres psql -U postgres -d solana_indexer
```

## Troubleshooting

### Indexer Can't Connect to Validator

**Problem:** `connection refused` errors

**Solution:** 
- Ensure validator is running
- For localnet, use `host.docker.internal:8899` in Docker
- Check firewall rules
- Verify RPC URL in `.env`

### Frontend Build Fails

**Problem:** Build errors during `docker-compose up`

**Solution:**
```bash
cd frontend
pnpm install
pnpm run type-check

docker-compose build frontend --no-cache
```

### Database Connection Issues

**Problem:** Indexer can't connect to PostgreSQL

**Solution:**
```bash
docker-compose exec postgres pg_isready -U postgres

docker-compose logs postgres

docker-compose down -v
docker-compose up -d
```

### Port Already in Use

**Problem:** `port 3000 already in use`

**Solution:**
```bash
lsof -ti:3000 | xargs kill

# Or change ports in docker-compose.yml
ports:
  - "3001:3000"
```

## Monitoring

### Check Service Health

```bash
curl http://localhost:8080/health

docker-compose ps

docker stats
```

### View Performance Metrics

```bash
curl http://localhost:8080/debug/pprof/

docker-compose exec indexer sh
ps aux
top
```

## Cleaning Up

### Stop Services (Keep Data)

```bash
docker-compose down
```

### Stop Services (Remove Volumes)

```bash
docker-compose down -v
```

### Remove Images

```bash
docker-compose down --rmi all
```

### Full Cleanup

```bash
docker-compose down -v --rmi all
docker system prune -a
```

## Advanced Configuration

### Custom Docker Compose File

Create `docker-compose.override.yml`:

```yaml
version: '3.8'

services:
  indexer:
    environment:
      LOG_LEVEL: debug
    volumes:
      - ./go_indexer:/app

  frontend:
    command: npm run dev
    volumes:
      - ./frontend:/app
      - /app/node_modules
```

### Multiple Environments

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Resource Limits

Edit `docker-compose.yml`:

```yaml
services:
  indexer:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and Push
        run: |
          docker-compose build
          docker-compose push
      
      - name: Deploy to Server
        run: |
          ssh user@server 'cd /app && docker-compose pull && docker-compose up -d'
```

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Go Indexer README](go_indexer/README.md)
- [Frontend README](frontend/README.md)
