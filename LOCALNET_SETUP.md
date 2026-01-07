# Localnet Development Setup

This guide shows how to set up a local Solana validator with cloned accounts for efficient development.

## Why Use Localnet with Cloned Accounts?

- **Fast iteration**: No rate limits, instant transactions
- **Cost-free**: No SOL needed for testing
- **Real data**: Clone actual accounts from devnet/mainnet
- **Offline development**: Work without internet
- **Consistent state**: Reset anytime with fresh state

## Quick Start

### 1. Start Basic Localnet

```bash
# Simple localnet validator
solana-test-validator

# With reset on each start
solana-test-validator --reset
```

### 2. Start Localnet with Cloned Accounts

Clone important accounts (Token Program, System Program extensions, etc.):

```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --clone metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s \
  --reset
```

**Common accounts to clone:**

- `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` - Token Program
- `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL` - Associated Token Program
- `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s` - Metaplex Token Metadata

### 3. Clone Specific Program

To clone a deployed program from devnet:

```bash
# Clone program with all its data
solana-test-validator \
  --clone <PROGRAM_ID> \
  --url devnet \
  --reset
```

### 4. Clone with Custom Ledger Path

```bash
solana-test-validator \
  --ledger .anchor/test-ledger \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --reset
```

## Development Workflow

### Terminal 1: Start Validator

```bash
# Start with cloned accounts
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset \
  --quiet
```

### Terminal 2: Deploy Programs

```bash
cd starter_program

# Set to localhost
solana config set --url localhost

# Deploy programs
anchor deploy

# Get program IDs
anchor keys list
```

### Terminal 3: Frontend

```bash
cd frontend

# Ensure .env.local points to localhost
cat .env.local
# NEXT_PUBLIC_SOLANA_RPC_HOST=http://localhost:8899
# NEXT_PUBLIC_SOLANA_NETWORK=localnet

# Start dev server
pnpm dev
```

### Terminal 4: Watch Logs (Optional)

```bash
solana logs
```

## Advanced Configuration

### Full-Featured Localnet

```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --clone metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s \
  --bpf-program gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC ./target/deploy/starter_program.so \
  --bpf-program CounzVsCGF4VzNkAwePKC9mXr6YWiFYF4kLW6YdV8Cc ./target/deploy/counter_program.so \
  --ledger .anchor/test-ledger \
  --reset \
  --quiet
```

### Clone Specific Accounts

To clone a token mint or specific account:

```bash
solana-test-validator \
  --clone <MINT_ADDRESS> \
  --clone <TOKEN_ACCOUNT_ADDRESS> \
  --url mainnet-beta \
  --reset
```

### Set Compute Unit Limits

```bash
solana-test-validator \
  --compute-unit-limit 1400000 \
  --reset
```

## Testing with Localnet

### Run Anchor Tests Against Localnet

```bash
# Start validator in another terminal first
solana-test-validator --reset

# Run tests
anchor test --skip-local-validator
```

### Run Specific Test File

```bash
anchor test --skip-local-validator tests/cross_program.ts
```

## Useful Commands

### Check Validator Status

```bash
solana cluster-version
solana ping
```

### Check Account Balance

```bash
solana balance
```

### Request Airdrop (Localnet)

```bash
solana airdrop 100
```

### List Programs

```bash
solana program show gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC
```

### Close Validator

```bash
# Just Ctrl+C in the terminal running solana-test-validator
```

## Common Issues

### Issue: "Address already in use"

```bash
# Kill existing validator
pkill -f solana-test-validator

# Or find and kill process
lsof -i :8899
kill -9 <PID>
```

### Issue: "Program not found"

```bash
# Rebuild and deploy
anchor build
anchor deploy
```

### Issue: "Transaction simulation failed"

```bash
# Check logs
solana logs

# Increase compute units if needed
solana-test-validator --compute-unit-limit 1400000 --reset
```

### Issue: Stale data after changes

```bash
# Always use --reset flag
solana-test-validator --reset
```

## Clone Strategy for Different Use Cases

### For Token Operations

```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --reset
```

### For NFT Development

```bash
solana-test-validator \
  --clone TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL \
  --clone metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s \
  --url mainnet-beta \
  --reset
```

### For Testing Real Protocols

```bash
# Example: Clone Jupiter program
solana-test-validator \
  --clone JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB \
  --url mainnet-beta \
  --reset
```

## Performance Tips

1. **Use --quiet**: Reduces log spam
2. **Use --reset**: Ensures clean state
3. **Clone only what you need**: Faster startup
4. **Use --ledger**: Persistent data between restarts (without --reset)
5. **Set compute limits**: Prevent resource exhaustion

## Integration with Anchor.toml

Update `Anchor.toml` for localnet:

```toml
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[test.validator]
url = "http://localhost:8899"

[[test.validator.clone]]
address = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"

[[test.validator.clone]]
address = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
```

Then simply run:

```bash
anchor test
# Automatically starts validator with cloned accounts
```

## Best Practices

1. **Always use --reset** during active development
2. **Clone accounts from mainnet** for production-like testing
3. **Clone from devnet** for faster sync
4. **Keep validator running** during dev session
5. **Restart validator** after program changes
6. **Use separate terminals** for validator, deploy, frontend, logs
7. **Check solana logs** when debugging transactions

## Quick Reference

```bash
# Start localnet
solana-test-validator --reset

# Set to localnet
solana config set --url localhost

# Deploy
anchor deploy

# Run tests
anchor test --skip-local-validator

# Watch logs
solana logs

# Stop validator
Ctrl+C (in validator terminal)
```

---

**For more information:**
- [Solana Test Validator Docs](https://docs.solana.com/developing/test-validator)
- [Anchor Testing Guide](https://www.anchor-lang.com/docs/testing)
