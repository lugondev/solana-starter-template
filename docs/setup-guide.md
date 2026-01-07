---
layout: default
title: Setup Guide
nav_order: 3
description: "First time setup guide for Solana Starter Program"
---

# Setup Guide - First Time Setup

This guide walks you through setting up the Solana Starter Program from scratch.

## Prerequisites Installation

### 1. Install Rust and Solana CLI

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

rustc --version
solana --version
```

### 2. Install Anchor

```bash
cargo install --git https://github.com/coral-xyz/anchor --tag v0.31.1 anchor-cli

anchor --version
```

### 3. Install Node.js and pnpm

```bash
curl -fsSL https://fnm.vercel.app/install | bash
fnm install 20
fnm use 20

npm install -g pnpm

node --version
pnpm --version
```

### 4. Install Go (for indexer)

```bash
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

go version
```

### 5. Install PostgreSQL (optional, for indexer)

```bash
brew install postgresql@16

# Or on Linux
sudo apt update
sudo apt install postgresql postgresql-contrib

# Or use Docker
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=solana_indexer \
  -p 5432:5432 \
  postgres:16-alpine
```

## Project Setup

### Step 1: Clone/Initialize Project

```bash
cd /Users/lugon/dev/2026-dev/solana-starter-program

ls -la
```

You should see:
```
starter_program/    # Anchor workspace
frontend/           # Next.js app
go_indexer/         # Go indexer
README.md           # Main documentation
```

### Step 2: Build Anchor Programs

```bash
cd starter_program

anchor build

ls target/deploy/
# Should see: starter_program.so, counter_program.so

anchor keys list
# Note the program IDs
```

### Step 3: Setup Frontend

```bash
cd ../frontend

pnpm install

cp .env.local.example .env.local

# Edit .env.local with your program IDs
nano .env.local
```

`.env.local` should contain:
```bash
NEXT_PUBLIC_SOLANA_RPC_HOST=http://localhost:8899
NEXT_PUBLIC_SOLANA_NETWORK=localnet
NEXT_PUBLIC_STARTER_PROGRAM_ID=<your-starter-program-id>
NEXT_PUBLIC_COUNTER_PROGRAM_ID=<your-counter-program-id>
```

Verify TypeScript:
```bash
pnpm run type-check
```

### Step 4: Setup Go Indexer

```bash
cd ../go_indexer

go mod download

cp .env.example .env

# Edit .env
nano .env
```

`.env` should contain:
```bash
SOLANA_RPC_URL=http://localhost:8899
SOLANA_WS_URL=ws://localhost:8900
DATABASE_URL=postgres://postgres:postgres@localhost:5432/solana_indexer?sslmode=disable
START_SLOT=0
POLL_INTERVAL_MS=1000
BATCH_SIZE=10
MAX_CONCURRENCY=5
SERVER_PORT=8080
LOG_LEVEL=info
```

Build indexer:
```bash
make build
# Or: go build -o indexer cmd/indexer/main.go

./indexer --version
```

### Step 5: Initialize Git Repository

```bash
cd ..

# Remove nested git repo if exists
rm -rf starter_program/.git

git add -A

git commit -m "Initial commit: Full-stack Solana starter

- Two Anchor programs (24 instructions total)
- Next.js 16 frontend with Wallet Adapter
- Go indexer with concurrent processing
- 27 passing integration tests
- Complete documentation and guides"

git branch -M main

# Optional: Add remote
git remote add origin https://github.com/yourusername/solana-starter-program.git
git push -u origin main
```

## Running the Stack

### Development Mode (4 Terminals)

**Terminal 1: Start Localnet Validator**
```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset \
  --quiet
```

**Terminal 2: Deploy Programs**
```bash
cd starter_program

solana config set --url localhost

anchor build && anchor deploy

# After deployment, update frontend/.env.local with new program IDs if changed
anchor keys list
```

**Terminal 3: Start Frontend**
```bash
cd frontend
pnpm dev

# Visit http://localhost:3000
```

**Terminal 4: Start Indexer (Optional)**
```bash
cd go_indexer
make run

# Or: go run cmd/indexer/main.go

# Verify: curl http://localhost:8080/health
```

### Docker Mode (1 Command)

```bash
# First, ensure programs are deployed and update .env.docker
cp .env.docker .env
nano .env  # Update program IDs

docker-compose up -d

docker-compose logs -f

# Access:
# - Frontend: http://localhost:3000
# - Indexer: http://localhost:8080
# - Database: localhost:5432
```

## Verification

### Run Full Test Suite

```bash
cd starter_program
anchor test

# Expected: ✔ 27 passing
```

### Run Frontend Type Check

```bash
cd frontend
pnpm run type-check

# Expected: No errors
```

### Run Indexer Tests

```bash
cd go_indexer
go test ./... -v

# Expected: All tests pass
```

### Run Full Stack Test Script

```bash
chmod +x test-full-stack.sh
./test-full-stack.sh
```

## First Interaction

### Using the Frontend

1. Open http://localhost:3000
2. Connect your wallet (Phantom/Solflare)
3. Request airdrop (on localnet):
   ```bash
   solana airdrop 2 <your-wallet-address>
   ```
4. Navigate to `/programs` page
5. Try these operations:
   - Create User Account (PDA)
   - Update User Points
   - Increment Counter
   - Test CPI Operations

### Using the CLI

```bash
# Set to localnet
solana config set --url localhost

# Get your wallet address
solana address

# Request airdrop
solana airdrop 2

# Check balance
solana balance

# View program account
solana account <program-id>
```

## Troubleshooting

### Validator Won't Start

**Issue:** Port 8899 already in use

**Solution:**
```bash
lsof -ti:8899 | xargs kill -9

solana-test-validator --reset
```

### Programs Won't Deploy

**Issue:** `Error: Account <address> already exists`

**Solution:**
```bash
solana-test-validator --reset

cd starter_program
anchor build && anchor deploy
```

### Frontend Build Errors

**Issue:** TypeScript errors or module not found

**Solution:**
```bash
cd frontend
rm -rf node_modules .next
pnpm install
pnpm run type-check
```

### Indexer Connection Errors

**Issue:** Can't connect to RPC

**Solution:**
```bash
# Check validator is running
solana cluster-version

# Check RPC URL in .env
cat go_indexer/.env | grep RPC_URL

# Restart indexer
cd go_indexer
make run
```

## Next Steps

After setup is complete:

1. **Read Documentation:**
   - [QUICKSTART.md](starter_program/QUICKSTART.md) - 5-minute tutorial
   - [CROSS_PROGRAM.md](starter_program/CROSS_PROGRAM.md) - CPI patterns
   - [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Indexer integration

2. **Explore the Code:**
   - Study program instructions in `starter_program/programs/`
   - Review frontend components in `frontend/components/features/`
   - Understand indexer logic in `go_indexer/internal/indexer/`

3. **Customize for Your Use Case:**
   - Add new program instructions
   - Build custom UI components
   - Implement program-specific indexing
   - Create analytics dashboards

4. **Deploy to Devnet:**
   ```bash
   solana config set --url devnet
   solana airdrop 2
   anchor deploy
   # Update .env files with devnet program IDs
   ```

5. **Deploy to Mainnet:**
   - Audit your programs
   - Test thoroughly on devnet
   - Use `solana program deploy` with upgrade authority
   - Monitor program performance

## Getting Help

- **Documentation:** Check all `*.md` files in this repo
- **Logs:** 
  - Validator: `solana logs`
  - Indexer: `docker-compose logs indexer`
  - Frontend: Browser console
- **Community:**
  - Solana Discord: https://discord.gg/solana
  - Anchor Discord: https://discord.gg/anchor
  - Stack Overflow: Tag `solana` or `anchor-solana`

## Project Structure Reference

```
solana-starter-program/
├── starter_program/          # Anchor workspace
│   ├── programs/
│   │   ├── starter_program/  # 18 instructions
│   │   └── counter_program/  # 6 instructions
│   ├── tests/                # 27 integration tests
│   └── target/               # Build artifacts
├── frontend/                 # Next.js 16 + React 19
│   ├── app/                  # App router pages
│   ├── components/           # React components
│   ├── lib/                  # Utilities and hooks
│   └── .env.local           # Environment config
├── go_indexer/               # High-performance indexer
│   ├── cmd/indexer/          # Main application
│   ├── internal/             # Core logic
│   ├── pkg/                  # Shared packages
│   └── .env                  # Indexer config
├── docker-compose.yml        # Full stack deployment
├── .gitignore                # Git ignore rules
└── README.md                 # Main documentation
```

## Success Criteria

Your setup is complete when:

- ✅ All programs compile with `anchor build`
- ✅ All 27 tests pass with `anchor test`
- ✅ Frontend builds with no TypeScript errors
- ✅ Indexer builds and runs without errors
- ✅ You can connect wallet and interact with programs
- ✅ Transactions are confirmed on-chain
- ✅ Indexer captures program events

**Congratulations! You're ready to build on Solana! 🚀**
