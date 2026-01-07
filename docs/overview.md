---
layout: default
title: Overview
nav_order: 2
description: "Complete project overview and features"
---

# Solana Starter Program - Complete Full-Stack Template

A production-ready Solana development template featuring Anchor programs, TypeScript SDK, Next.js frontend, and high-performance Go indexer with complete cross-program invocation (CPI) patterns.

## 🚀 Project Overview

This monorepo contains:
- **Two Anchor Programs** (Rust) - `starter_program` & `counter_program`
- **Next.js 16 Frontend** - Full-featured UI with Wallet Adapter
- **Go Indexer** - High-performance blockchain indexer with concurrent processing
- **Complete Test Suite** - 27 passing tests
- **Type-Safe Integration** - Anchor IDL → TypeScript types
- **Production Patterns** - PDAs, CPI, SPL tokens, error handling

## 📁 Project Structure

```
solana-starter-program/
├── starter_program/          # Anchor workspace
│   ├── programs/
│   │   ├── starter_program/  # Main program (18 instructions)
│   │   └── counter_program/  # Counter with payment (6 instructions)
│   ├── tests/                # Integration tests (27 passing)
│   ├── target/
│   │   ├── idl/              # Generated IDL files
│   │   └── types/            # TypeScript types
│   └── Anchor.toml
├── frontend/                 # Next.js 16 + React 19
│   ├── app/
│   │   ├── programs/         # Programs demo page
│   │   └── dashboard/        # Dashboard
│   ├── components/
│   │   └── features/
│   │       ├── counter/      # Counter components
│   │       ├── starter/      # Starter program components
│   │       └── wallet/       # Wallet integration
│   ├── lib/
│   │   ├── anchor/           # Anchor integration
│   │   │   ├── idl/          # IDL JSON files
│   │   │   ├── types/        # Generated types
│   │   │   └── program.ts    # Program helpers
│   │   └── hooks/            # Custom React hooks
│   └── package.json
├── go_indexer/               # High-performance Go indexer
│   ├── cmd/indexer/          # Main application
│   ├── internal/
│   │   ├── config/           # Configuration management
│   │   ├── indexer/          # Core indexer logic
│   │   ├── repository/       # Data access layer
│   │   └── handler/          # HTTP handlers
│   ├── pkg/solana/           # Solana client library
│   └── docs/                 # Indexer documentation
├── LOCALNET_SETUP.md         # Localnet configuration guide
└── README.md                 # This file
```

## ⚡ Quick Start

### Prerequisites

- Node.js 18+ or Bun
- Rust 1.75+
- Solana CLI 1.18+
- Anchor 0.31.1+
- pnpm (recommended)
- Go 1.21+ (for indexer)
- PostgreSQL (optional, for indexer persistence)

### 1. Install Dependencies

```bash
# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor --tag v0.31.1 anchor-cli

# Verify installations
solana --version
anchor --version
```

### 2. Setup Programs (Localnet)

```bash
cd starter_program

# Build programs
anchor build

# Run tests (should see 27 passing)
anchor test

# Start local validator with cloned accounts (separate terminal)
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset \
  --quiet

# Set to localnet
solana config set --url localhost

# Deploy locally
anchor deploy

# Get program addresses
anchor keys list
```

**See [LOCALNET_SETUP.md](LOCALNET_SETUP.md) for detailed localnet configuration.**

### 3. Setup Frontend

```bash
cd frontend

# Install dependencies
pnpm install

# Copy and configure environment variables
cp .env.local.example .env.local

# Verify configuration (should point to localhost:8899)
cat .env.local
# NEXT_PUBLIC_SOLANA_RPC_HOST=http://localhost:8899
# NEXT_PUBLIC_SOLANA_NETWORK=localnet
# NEXT_PUBLIC_STARTER_PROGRAM_ID=gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC
# NEXT_PUBLIC_COUNTER_PROGRAM_ID=CounzVsCGF4VzNkAwePKC9mXr6YWiFYF4kLW6YdV8Cc

# Start dev server
pnpm dev

# Visit http://localhost:3000
# Click "Connect Wallet" and use a browser wallet (Phantom/Solflare)
```

### 4. Setup Go Indexer (Optional)

```bash
cd go_indexer

# Install dependencies
go mod download

# Copy environment variables
cp .env.example .env

# Update .env with your Solana RPC endpoint
# For localnet:
# SOLANA_RPC_URL=http://localhost:8899
# SOLANA_WS_URL=ws://localhost:8900

# Build the indexer
make build

# Run the indexer
make run

# Or run directly
go run cmd/indexer/main.go

# Check indexer health
curl http://localhost:8080/health
```

**See [go_indexer/README.md](go_indexer/README.md) for detailed indexer documentation.**

## 🎯 Features

### Starter Program (18 Instructions)

**Program Configuration:**
- `initialize` - One-time program setup
- `initialize_config` - Create program config PDA
- `update_config` - Update admin and fee settings
- `toggle_pause` - Emergency pause mechanism

**User Account Management (PDA):**
- `create_user_account` - Create user PDA with points
- `update_user_account` - Update user points
- `close_user_account` - Close and reclaim rent

**SPL Token Operations:**
- `create_mint` - Create mint with PDA authority
- `mint_tokens` - Mint tokens to user
- `transfer_tokens` - Transfer between accounts
- `transfer_tokens_with_pda` - Transfer using PDA signer
- `burn_tokens` - Burn tokens from account

**Cross-Program Invocation (CPI):**
- `transfer_sol` - Simple SOL transfer
- `transfer_sol_with_pda` - Transfer from PDA vault
- `initialize_counter` - Init counter via CPI
- `increment_counter` - Increment via CPI
- `add_to_counter` - Add value via CPI
- `increment_multiple` - Multiple CPIs in one tx
- `increment_with_payment_from_pda` - PDA pays for service

### Counter Program (6 Instructions)

- `initialize` - Create counter PDA
- `increment` - Add 1 to counter
- `decrement` - Subtract 1 from counter
- `add` - Add arbitrary value
- `reset` - Reset to 0 (authority only)
- `increment_with_payment` - Increment with SOL payment

### Frontend Features

**UI Components:**
- `UserAccount` - Create/update/close user accounts
- `CounterDisplay` - Full counter operations
- `CrossProgramDemo` - Interactive CPI demonstration
- `WalletButton` - Multi-wallet support (Phantom, Solflare)
- `WalletBalance` - Real-time balance with WebSocket

**React Hooks:**
- `useStarterProgram` - Type-safe program interactions
- `useCounterProgram` - Counter operations with SWR
- `useBalance` - Real-time balance updates
- `useSendTransaction` - Transaction handling

**Technical Stack:**
- Next.js 16.1.1 with App Router
- React 19
- TypeScript 5.9 (strict mode)
- Anchor 0.32.1 (frontend SDK)
- SWR for data fetching
- Tailwind CSS 4

### Go Indexer Features

**Core Capabilities:**
- 🚀 High-performance concurrent block processing
- 🔄 Automatic retry with exponential backoff
- 📊 Real-time slot tracking and monitoring
- 🛡️ Graceful shutdown handling
- 🧪 Comprehensive test coverage (80%+)
- 🐳 Docker support with multi-stage builds

**Architecture:**
- **Concurrent Processing** - Configurable worker pools for parallel block processing
- **Error Recovery** - Automatic retry logic for failed operations
- **Health Monitoring** - HTTP health check endpoint at `/health`
- **Slot Tracking** - Real-time latest slot monitoring
- **Database Support** - PostgreSQL integration (optional)
- **Metrics** - Built-in performance monitoring with pprof

**Configuration:**
- Configurable batch size and polling intervals
- Max concurrency control for optimal resource usage
- Multiple database backend support
- Environment-based configuration

**Use Cases:**
- Index program transactions in real-time
- Track account changes and state updates
- Build analytics dashboards
- Monitor on-chain events
- Create custom notification systems

## 📖 Documentation

Comprehensive documentation available:

- **[QUICKSTART.md](starter_program/QUICKSTART.md)** - 5-minute setup guide
- **[README.md](starter_program/README.md)** - Full API reference (560+ lines)
- **[CROSS_PROGRAM.md](starter_program/CROSS_PROGRAM.md)** - Complete CPI guide (820+ lines)
- **[PROJECT_SUMMARY.md](starter_program/PROJECT_SUMMARY.md)** - Project overview (540+ lines)
- **[Frontend README](frontend/README.md)** - Frontend documentation
- **[Indexer README](go_indexer/README.md)** - Go indexer documentation
- **[LOCALNET_SETUP.md](LOCALNET_SETUP.md)** - Localnet configuration guide

## 🧪 Testing

### Run All Tests

```bash
cd starter_program
anchor test
```

**Expected Output:**
```
✔ 27 passing (20s)
- 14 cross-program tests
- 13 starter program tests
```

### Test Coverage

**Cross-Program Tests:**
- Direct counter operations (4 tests)
- CPI from starter to counter (4 tests)
- Complex scenarios (3 tests)
- Payment functions (3 tests)

**Starter Program Tests:**
- Initialization (1 test)
- Configuration management (3 tests)
- User account operations (3 tests)
- SPL token operations (4 tests)
- CPI operations (2 tests)

## 🏗️ Development Workflow

### Local Development (Recommended)

**Terminal 1: Start Localnet Validator**
```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset \
  --quiet
```

**Terminal 2: Build & Deploy Programs**
```bash
cd starter_program

# Set to localhost (first time only)
solana config set --url localhost

# Build
anchor build

# Deploy
anchor deploy

# After code changes, rebuild and redeploy
anchor build && anchor deploy
```

**Terminal 3: Frontend Dev Server**
```bash
cd frontend
pnpm dev
```

**Terminal 4: Go Indexer (Optional)**
```bash
cd go_indexer

# Make sure RPC points to localnet in .env
# SOLANA_RPC_URL=http://localhost:8899

make run
# Or: go run cmd/indexer/main.go

# Check indexer is running
curl http://localhost:8080/health
```

**Terminal 5: Watch Logs (Optional)**
```bash
solana logs
```

**See [LOCALNET_SETUP.md](LOCALNET_SETUP.md) for advanced configurations.**

### Deploy to Devnet

```bash
# Set cluster to devnet
solana config set --url devnet

# Request airdrop
solana airdrop 2

# Build programs
anchor build

# Deploy
anchor deploy

# Update program IDs in frontend/.env.local
# NEXT_PUBLIC_STARTER_PROGRAM_ID=<new_id>
# NEXT_PUBLIC_COUNTER_PROGRAM_ID=<new_id>
```

### Update IDL After Changes

```bash
# Rebuild programs
cd starter_program
anchor build

# Copy new IDL and types to frontend
cp target/idl/*.json ../frontend/lib/anchor/idl/
cp target/types/*.ts ../frontend/lib/anchor/types/

# Restart frontend dev server
cd ../frontend
pnpm dev
```

## 🔑 Key Concepts Demonstrated

### 1. Program Derived Addresses (PDAs)

```rust
// Rust: PDA derivation
let (config_pda, bump) = Pubkey::find_program_address(
    &[b"program_config"],
    program_id
);

// TypeScript: Same derivation
const [configPda, bump] = PublicKey.findProgramAddressSync(
  [Buffer.from('program_config')],
  programId
);
```

### 2. Cross-Program Invocation (CPI)

```rust
// Rust: Call another program
counter_program::cpi::increment(
    CpiContext::new(
        ctx.accounts.counter_program.to_account_info(),
        counter_program::cpi::accounts::Increment {
            counter: ctx.accounts.counter.to_account_info(),
        },
    )
)?;
```

### 3. PDA Signing

```rust
// Rust: PDA signs transaction
let seeds = &[SEED_TOKEN_VAULT, &[vault_bump]];
let signer = &[&seeds[..]];

system_program::transfer(
    CpiContext::new_with_signer(
        ctx.accounts.system_program.to_account_info(),
        Transfer { from, to },
        signer,
    ),
    amount,
)?;
```

### 4. Type-Safe Frontend

```typescript
// TypeScript: Fully typed program interaction
const tx = await program.methods
  .createUserAccount()
  .accountsPartial({
    authority: wallet.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

## 🎓 Learning Resources

### For Beginners

1. Start with [QUICKSTART.md](starter_program/QUICKSTART.md)
2. Follow 4 use cases (10 minutes each)
3. Read [README.md](starter_program/README.md) API reference
4. Experiment with frontend at `/programs` page

### For Intermediate

1. Study [CROSS_PROGRAM.md](starter_program/CROSS_PROGRAM.md)
2. Understand 5 CPI patterns
3. Review test files for examples
4. Implement custom instructions

### For Advanced

1. Read program source code
2. Study security patterns
3. Optimize compute units
4. Build production features
5. Customize Go indexer for specific program events
6. Implement custom analytics and monitoring

## 📊 Project Statistics

- **Total Code:** ~8,000+ lines
  - Rust programs: ~2,600 lines
  - TypeScript tests: ~700 lines
  - Frontend code: ~1,200 lines
  - Go indexer: ~1,500 lines
  - Documentation: ~2,000+ lines

- **Programs:** 2 programs, 24 instructions total
- **Tests:** 27 integration tests (100% passing)
- **Components:** 8+ React components
- **Hooks:** 6+ custom React hooks
- **Indexer:** Full-featured with concurrent processing

## 🔐 Security Best Practices

All programs implement:

- ✅ Account validation with `has_one` constraints
- ✅ Authority checks on sensitive operations
- ✅ Arithmetic overflow protection
- ✅ Rent-exempt account validation
- ✅ PDA bump seed storage
- ✅ Comprehensive error handling
- ✅ Emergency pause mechanism

## 🐛 Known Issues

None! All tests passing ✓

Previous issues fixed:
- ~~Toggle pause test missing signer~~ ✓ Fixed
- ~~Transfer SOL with PDA insufficient rent~~ ✓ Fixed

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Solana Foundation for the blockchain platform
- Anchor team for the framework
- Solana community for resources and support

## 📞 Support

- **Issues:** Open a GitHub issue
- **Discussions:** GitHub Discussions
- **Solana Discord:** Join #anchor channel
- **Documentation:** Check `/starter_program/*.md` files

## 🚦 Getting Help

**Common Issues:**

1. **Build fails:** Run `anchor clean && anchor build`
2. **Tests fail:** Ensure local validator is NOT running during `anchor test`
3. **Frontend errors:** Check program IDs in `.env.local`
4. **Type errors:** Rebuild programs and copy fresh IDL/types

**Development Tips:**

- Use `solana logs` to debug transactions
- Check `target/idl/*.json` for instruction names
- Read error codes in `programs/*/src/error.rs`
- Test locally before deploying to devnet

---

**Built with ❤️ using Anchor, Solana, and Next.js**

*Ready for production • Fully tested • Type-safe • Well-documented*
