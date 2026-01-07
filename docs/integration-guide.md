---
layout: default
title: Integration Guide
nav_order: 6
description: "How to integrate the Go indexer with Anchor programs"
---

# Integration Guide - Indexer + Anchor Programs

This guide demonstrates how to integrate the Go indexer with your Anchor programs to track on-chain events and build real-time applications.

## 🎯 Overview

The Go indexer can monitor your deployed Anchor programs and:
- Track all program transactions in real-time
- Index account state changes
- Build custom analytics dashboards
- Send notifications for specific events
- Store historical data in PostgreSQL

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Indexing Program Transactions](#indexing-program-transactions)
4. [Custom Event Handling](#custom-event-handling)
5. [Database Schema](#database-schema)
6. [API Endpoints](#api-endpoints)
7. [Production Deployment](#production-deployment)

---

## Quick Start

### 1. Start Full Stack (4 Terminals)

**Terminal 1: Localnet Validator**
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
anchor keys list  # Note the program IDs
```

**Terminal 3: Start Indexer**
```bash
cd go_indexer
cp .env.example .env

# Edit .env and configure:
# SOLANA_RPC_URL=http://localhost:8899
# SOLANA_WS_URL=ws://localhost:8900
# START_SLOT=0
# POLL_INTERVAL_MS=1000
# BATCH_SIZE=10
# MAX_CONCURRENCY=5
# SERVER_PORT=8080

make run
```

**Terminal 4: Frontend (Optional)**
```bash
cd frontend
pnpm dev
```

### 2. Verify Indexer is Running

```bash
# Check health
curl http://localhost:8080/health
# Expected: {"status":"healthy","timestamp":"2024-01-07T..."}

# Check current slot
curl http://localhost:8080/api/v1/slot/latest
```

---

## Configuration

### Environment Variables

Create `go_indexer/.env` with these settings:

```bash
# Solana Configuration
SOLANA_RPC_URL=http://localhost:8899
SOLANA_WS_URL=ws://localhost:8900

# Indexing Configuration
START_SLOT=0                    # Start from genesis (or specific slot)
POLL_INTERVAL_MS=1000           # Check for new blocks every 1 second
BATCH_SIZE=10                   # Process 10 blocks at a time
MAX_CONCURRENCY=5               # Use 5 concurrent workers

# Program IDs to Monitor (from anchor keys list)
PROGRAM_ID_STARTER=gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC
PROGRAM_ID_COUNTER=CounzVsCGF4VzNkAwePKC9mXr6YWiFYF4kLW6YdV8Cc

# Database (Optional)
DATABASE_URL=postgres://user:password@localhost:5432/solana_indexer?sslmode=disable

# Server Configuration
SERVER_PORT=8080
LOG_LEVEL=info                  # debug, info, warn, error
```

### For Devnet

```bash
SOLANA_RPC_URL=https://api.devnet.solana.com
SOLANA_WS_URL=wss://api.devnet.solana.com
START_SLOT=latest               # Start from current slot
POLL_INTERVAL_MS=5000           # Poll every 5 seconds (rate limit)
```

### For Mainnet-Beta

```bash
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
SOLANA_WS_URL=wss://api.mainnet-beta.solana.com
START_SLOT=latest
POLL_INTERVAL_MS=10000          # Poll every 10 seconds (rate limit)
BATCH_SIZE=5                    # Smaller batches for rate limits
```

---

## Indexing Program Transactions

### Basic Flow

1. **Indexer polls for new blocks** every `POLL_INTERVAL_MS`
2. **Fetches block data** including all transactions
3. **Filters transactions** by program ID
4. **Parses instruction data** using Anchor IDL
5. **Stores data** in database (optional)
6. **Emits events** for real-time updates

### Example: Monitor User Account Creation

When someone calls `create_user_account` on starter_program:

```rust
// Program instruction (Rust)
pub fn create_user_account(ctx: Context<CreateUserAccount>) -> Result<()> {
    let account = &mut ctx.accounts.user_account;
    account.authority = ctx.accounts.authority.key();
    account.points = 0;
    // ...
    Ok(())
}
```

The indexer can capture:
- Transaction signature
- Block timestamp
- User authority (wallet address)
- PDA address
- Initial points value
- Transaction fee paid

### Customize Indexer to Track Your Programs

Edit `go_indexer/internal/indexer/processor.go`:

```go
package indexer

import (
    "context"
    "fmt"
    "log"
)

// ProcessBlock handles a single block
func (idx *Indexer) ProcessBlock(ctx context.Context, slot uint64) error {
    // Get block data
    block, err := idx.client.GetBlock(ctx, slot)
    if err != nil {
        return fmt.Errorf("failed to get block %d: %w", slot, err)
    }

    // Filter transactions by your program IDs
    starterProgramID := "gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC"
    counterProgramID := "CounzVsCGF4VzNkAwePKC9mXr6YWiFYF4kLW6YdV8Cc"

    for _, tx := range block.Transactions {
        // Parse transaction
        for _, ix := range tx.Message.Instructions {
            programID := tx.Message.AccountKeys[ix.ProgramIDIndex]

            switch programID {
            case starterProgramID:
                if err := idx.handleStarterProgram(ctx, tx, ix); err != nil {
                    log.Printf("Error handling starter program: %v", err)
                }
            case counterProgramID:
                if err := idx.handleCounterProgram(ctx, tx, ix); err != nil {
                    log.Printf("Error handling counter program: %v", err)
                }
            }
        }
    }

    return nil
}

// Handle starter_program instructions
func (idx *Indexer) handleStarterProgram(ctx context.Context, tx Transaction, ix Instruction) error {
    // Parse instruction discriminator (first 8 bytes)
    discriminator := ix.Data[:8]

    // Map discriminators to instruction names
    // You can get these from target/idl/starter_program.json
    switch string(discriminator) {
    case "create_user_account":
        return idx.handleCreateUserAccount(ctx, tx, ix)
    case "update_user_account":
        return idx.handleUpdateUserAccount(ctx, tx, ix)
    case "increment_counter":
        return idx.handleIncrementCounter(ctx, tx, ix)
    // Add more cases...
    }

    return nil
}

// Example: Handle create_user_account instruction
func (idx *Indexer) handleCreateUserAccount(ctx context.Context, tx Transaction, ix Instruction) error {
    // Parse accounts from instruction
    authority := ix.Accounts[0]  // First account is authority
    userPDA := ix.Accounts[1]     // Second account is user PDA

    // Store in database
    if idx.repository != nil {
        event := &UserAccountCreatedEvent{
            Signature:   tx.Signature,
            Slot:        tx.Slot,
            BlockTime:   tx.BlockTime,
            Authority:   authority.String(),
            UserPDA:     userPDA.String(),
            InitialPoints: 0,
        }
        return idx.repository.SaveUserAccountCreated(ctx, event)
    }

    log.Printf("User account created: authority=%s, pda=%s", authority, userPDA)
    return nil
}
```

---

## Custom Event Handling

### Define Event Types

Create `go_indexer/internal/types/events.go`:

```go
package types

import "time"

// UserAccountCreatedEvent represents a create_user_account instruction
type UserAccountCreatedEvent struct {
    Signature     string    `json:"signature"`
    Slot          uint64    `json:"slot"`
    BlockTime     time.Time `json:"block_time"`
    Authority     string    `json:"authority"`
    UserPDA       string    `json:"user_pda"`
    InitialPoints uint64    `json:"initial_points"`
}

// UserAccountUpdatedEvent represents an update_user_account instruction
type UserAccountUpdatedEvent struct {
    Signature   string    `json:"signature"`
    Slot        uint64    `json:"slot"`
    BlockTime   time.Time `json:"block_time"`
    UserPDA     string    `json:"user_pda"`
    OldPoints   uint64    `json:"old_points"`
    NewPoints   uint64    `json:"new_points"`
}

// CounterIncrementedEvent represents an increment instruction
type CounterIncrementedEvent struct {
    Signature   string    `json:"signature"`
    Slot        uint64    `json:"slot"`
    BlockTime   time.Time `json:"block_time"`
    CounterPDA  string    `json:"counter_pda"`
    OldValue    uint64    `json:"old_value"`
    NewValue    uint64    `json:"new_value"`
    IncrementBy uint64    `json:"increment_by"`
}
```

### Real-Time Event Broadcasting

Add WebSocket support for real-time events:

```go
// go_indexer/internal/handler/websocket.go
package handler

import (
    "encoding/json"
    "net/http"
    "github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        return true // Allow all origins in dev
    },
}

type EventBroadcaster struct {
    clients map[*websocket.Conn]bool
    broadcast chan interface{}
}

func NewEventBroadcaster() *EventBroadcaster {
    return &EventBroadcaster{
        clients: make(map[*websocket.Conn]bool),
        broadcast: make(chan interface{}, 100),
    }
}

func (eb *EventBroadcaster) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        return
    }
    defer conn.Close()

    eb.clients[conn] = true
    defer delete(eb.clients, conn)

    // Keep connection alive
    for {
        select {
        case event := <-eb.broadcast:
            data, _ := json.Marshal(event)
            if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
                return
            }
        }
    }
}

func (eb *EventBroadcaster) Broadcast(event interface{}) {
    eb.broadcast <- event
}
```

---

## Database Schema

### PostgreSQL Schema

Create tables to store indexed data:

```sql
-- Create database
CREATE DATABASE solana_indexer;

-- Blocks table
CREATE TABLE blocks (
    slot BIGINT PRIMARY KEY,
    block_hash TEXT NOT NULL,
    block_time TIMESTAMP NOT NULL,
    parent_slot BIGINT NOT NULL,
    transactions_count INT NOT NULL,
    indexed_at TIMESTAMP DEFAULT NOW()
);

-- Transactions table
CREATE TABLE transactions (
    signature TEXT PRIMARY KEY,
    slot BIGINT NOT NULL REFERENCES blocks(slot),
    block_time TIMESTAMP NOT NULL,
    fee BIGINT NOT NULL,
    success BOOLEAN NOT NULL,
    error TEXT,
    indexed_at TIMESTAMP DEFAULT NOW()
);

-- User accounts table (from starter_program)
CREATE TABLE user_accounts (
    pda TEXT PRIMARY KEY,
    authority TEXT NOT NULL,
    points BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    created_tx TEXT NOT NULL REFERENCES transactions(signature),
    created_slot BIGINT NOT NULL
);

CREATE INDEX idx_user_accounts_authority ON user_accounts(authority);

-- User account events table
CREATE TABLE user_account_events (
    id SERIAL PRIMARY KEY,
    signature TEXT NOT NULL REFERENCES transactions(signature),
    slot BIGINT NOT NULL,
    block_time TIMESTAMP NOT NULL,
    event_type TEXT NOT NULL, -- 'created', 'updated', 'closed'
    pda TEXT NOT NULL,
    authority TEXT NOT NULL,
    old_points BIGINT,
    new_points BIGINT,
    indexed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_account_events_pda ON user_account_events(pda);
CREATE INDEX idx_user_account_events_authority ON user_account_events(authority);
CREATE INDEX idx_user_account_events_slot ON user_account_events(slot);

-- Counters table (from counter_program)
CREATE TABLE counters (
    pda TEXT PRIMARY KEY,
    authority TEXT NOT NULL,
    value BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    created_tx TEXT NOT NULL REFERENCES transactions(signature)
);

-- Counter events table
CREATE TABLE counter_events (
    id SERIAL PRIMARY KEY,
    signature TEXT NOT NULL REFERENCES transactions(signature),
    slot BIGINT NOT NULL,
    block_time TIMESTAMP NOT NULL,
    event_type TEXT NOT NULL, -- 'initialized', 'incremented', 'decremented', 'reset'
    pda TEXT NOT NULL,
    old_value BIGINT,
    new_value BIGINT,
    change_amount BIGINT,
    indexed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_counter_events_pda ON counter_events(pda);
CREATE INDEX idx_counter_events_slot ON counter_events(slot);
```

### Repository Implementation

Create `go_indexer/internal/repository/postgres.go`:

```go
package repository

import (
    "context"
    "database/sql"
    _ "github.com/lib/pq"
)

type PostgresRepository struct {
    db *sql.DB
}

func NewPostgresRepository(connString string) (*PostgresRepository, error) {
    db, err := sql.Open("postgres", connString)
    if err != nil {
        return nil, err
    }
    return &PostgresRepository{db: db}, nil
}

func (r *PostgresRepository) SaveUserAccountCreated(ctx context.Context, event *UserAccountCreatedEvent) error {
    query := `
        INSERT INTO user_account_events (signature, slot, block_time, event_type, pda, authority, new_points)
        VALUES ($1, $2, $3, 'created', $4, $5, $6)
    `
    _, err := r.db.ExecContext(ctx, query, 
        event.Signature, event.Slot, event.BlockTime,
        event.UserPDA, event.Authority, event.InitialPoints,
    )
    return err
}

// Add more repository methods...
```

---

## API Endpoints

### Add REST API to Query Indexed Data

Create `go_indexer/internal/handler/api.go`:

```go
package handler

import (
    "encoding/json"
    "net/http"
)

type APIHandler struct {
    repository Repository
}

// GET /api/v1/user-accounts/:authority
func (h *APIHandler) GetUserAccountsByAuthority(w http.ResponseWriter, r *http.Request) {
    authority := r.URL.Query().Get("authority")
    
    accounts, err := h.repository.GetUserAccountsByAuthority(r.Context(), authority)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(accounts)
}

// GET /api/v1/user-accounts/:pda/history
func (h *APIHandler) GetUserAccountHistory(w http.ResponseWriter, r *http.Request) {
    pda := r.URL.Query().Get("pda")
    
    events, err := h.repository.GetUserAccountEvents(r.Context(), pda)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(events)
}

// GET /api/v1/counters/:pda
func (h *APIHandler) GetCounter(w http.ResponseWriter, r *http.Request) {
    pda := r.URL.Query().Get("pda")
    
    counter, err := h.repository.GetCounter(r.Context(), pda)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(counter)
}

// GET /api/v1/stats
func (h *APIHandler) GetStats(w http.ResponseWriter, r *http.Request) {
    stats := map[string]interface{}{
        "total_users": h.repository.CountUserAccounts(r.Context()),
        "total_counters": h.repository.CountCounters(r.Context()),
        "total_transactions": h.repository.CountTransactions(r.Context()),
        "latest_slot": h.repository.GetLatestSlot(r.Context()),
    }

    json.NewEncoder(w).Encode(stats)
}
```

### Example API Responses

**GET `/api/v1/user-accounts?authority=9we6kjtbcZ2vy3GSLLsZTEhbAqXPTRvEyoxa8wxSqKp5`**
```json
[
  {
    "pda": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
    "authority": "9we6kjtbcZ2vy3GSLLsZTEhbAqXPTRvEyoxa8wxSqKp5",
    "points": 150,
    "created_at": "2024-01-07T10:30:00Z",
    "updated_at": "2024-01-07T11:45:00Z",
    "created_tx": "5Jb9..."
  }
]
```

**GET `/api/v1/user-accounts/7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU/history`**
```json
[
  {
    "signature": "5Jb9...",
    "slot": 12345,
    "block_time": "2024-01-07T10:30:00Z",
    "event_type": "created",
    "old_points": null,
    "new_points": 0
  },
  {
    "signature": "8Kc3...",
    "slot": 12567,
    "block_time": "2024-01-07T11:45:00Z",
    "event_type": "updated",
    "old_points": 0,
    "new_points": 150
  }
]
```

---

## Production Deployment

### Docker Deployment

Use the existing `go_indexer/Dockerfile`:

```bash
cd go_indexer

# Build image
docker build -t solana-indexer:latest .

# Run container
docker run -d \
  --name solana-indexer \
  -p 8080:8080 \
  -e SOLANA_RPC_URL=https://api.mainnet-beta.solana.com \
  -e DATABASE_URL=postgres://... \
  solana-indexer:latest
```

### Docker Compose (Full Stack)

See root `docker-compose.yml` for full stack deployment including:
- PostgreSQL database
- Go indexer
- Solana validator (localnet)
- Frontend (optional)

### Monitoring

```bash
# Check indexer logs
docker logs -f solana-indexer

# Monitor performance
curl http://localhost:8080/debug/pprof/

# Check health
curl http://localhost:8080/health
```

### Scaling Considerations

For production:
- Use dedicated RPC providers (QuickNode, Alchemy, Helius)
- Enable database connection pooling
- Add Redis for caching
- Implement rate limiting
- Use horizontal scaling with multiple indexer instances
- Add monitoring (Prometheus, Grafana)
- Set up alerts for failed transactions

---

## Example Use Cases

### 1. User Points Leaderboard

Track all `update_user_account` events and rank users by points:

```sql
SELECT authority, SUM(new_points) as total_points
FROM user_account_events
WHERE event_type = 'updated'
GROUP BY authority
ORDER BY total_points DESC
LIMIT 10;
```

### 2. Counter Analytics

Track counter increment patterns:

```sql
SELECT 
    DATE_TRUNC('hour', block_time) as hour,
    COUNT(*) as increment_count,
    SUM(change_amount) as total_change
FROM counter_events
WHERE event_type = 'incremented'
GROUP BY hour
ORDER BY hour DESC;
```

### 3. Real-Time Notifications

Send webhook when user reaches milestone:

```go
func (idx *Indexer) handleUpdateUserAccount(ctx context.Context, tx Transaction, ix Instruction) error {
    // Parse new points
    newPoints := parsePoints(ix.Data)
    
    // Check milestone
    if newPoints >= 1000 {
        // Send notification
        idx.webhookClient.Send(Notification{
            Type: "milestone_reached",
            User: authority,
            Points: newPoints,
        })
    }
    
    return nil
}
```

---

## Next Steps

1. **Customize Event Handlers** - Add logic for your specific program instructions
2. **Set Up Database** - Create PostgreSQL schema and repository layer
3. **Add API Endpoints** - Expose indexed data via REST API
4. **Build Frontend Dashboard** - Create analytics UI using indexed data
5. **Deploy to Production** - Use Docker and monitoring tools

---

## Resources

- **Solana RPC Docs:** https://docs.solana.com/api/http
- **Anchor IDL Format:** https://www.anchor-lang.com/docs/idl
- **Go Indexer README:** [go_indexer/README.md](go_indexer/README.md)
- **Program Documentation:** [starter_program/README.md](starter_program/README.md)

---

**Built with ❤️ for the Solana ecosystem**
