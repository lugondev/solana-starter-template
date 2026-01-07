# Quick Reference Card

## 🚀 One-Page Cheat Sheet

### Start Development (4 Terminals)

```bash
# Terminal 1: Validator
solana-test-validator --reset --quiet

# Terminal 2: Programs
cd starter_program && anchor build && anchor deploy

# Terminal 3: Frontend  
cd frontend && pnpm dev

# Terminal 4: Indexer
cd go_indexer && make run
```

### Essential Commands

```bash
# Build & Test
anchor build                    # Compile programs
anchor test                     # Run all tests
pnpm run type-check            # Check TypeScript
go test ./...                   # Test indexer

# Deploy
anchor deploy                   # Deploy to current cluster
anchor keys list                # Show program IDs

# Solana CLI
solana config set --url localhost    # Switch to localnet
solana airdrop 2                     # Get test SOL
solana balance                       # Check balance
solana logs                          # Watch transactions
```

### Docker Quick Start

```bash
docker-compose up -d            # Start all services
docker-compose logs -f          # View logs
docker-compose down             # Stop services
docker-compose ps               # Check status
```

### URLs

- Frontend: http://localhost:3000
- Indexer API: http://localhost:8080
- Health Check: http://localhost:8080/health
- Program Demo: http://localhost:3000/programs

### Environment Files

```bash
# Frontend
frontend/.env.local
NEXT_PUBLIC_SOLANA_RPC_HOST=http://localhost:8899
NEXT_PUBLIC_STARTER_PROGRAM_ID=<program-id>

# Indexer  
go_indexer/.env
SOLANA_RPC_URL=http://localhost:8899
DATABASE_URL=postgres://...

# Docker
.env (or .env.docker)
```

### Program IDs

```bash
# Get current IDs
cd starter_program && anchor keys list

# Example output:
# starter_program: gARh1g6...
# counter_program: CounzVs...
```

### Common Issues

| Problem | Solution |
|---------|----------|
| Port 8899 in use | `lsof -ti:8899 \| xargs kill -9` |
| Programs won't deploy | `solana-test-validator --reset` |
| Frontend type errors | `rm -rf node_modules && pnpm install` |
| Git nested repo | `rm -rf starter_program/.git` |

### Project Structure

```
├── starter_program/    # Anchor programs (Rust)
├── frontend/          # Next.js app (TypeScript)
├── go_indexer/        # Blockchain indexer (Go)
├── *.md              # Documentation (11 files)
└── docker-compose.yml # Full stack deployment
```

### Key Files

| File | Purpose |
|------|---------|
| README.md | Main documentation |
| SETUP_GUIDE.md | First-time setup |
| INTEGRATION_GUIDE.md | Indexer integration |
| DOCKER_DEPLOYMENT.md | Docker guide |
| test-full-stack.sh | Automated testing |

### Verification Checklist

```bash
# Check everything is ready
./test-full-stack.sh

# Or manually:
anchor build                    # ✓ Programs compile
anchor test                     # ✓ 27 tests pass  
cd frontend && pnpm run type-check  # ✓ No TS errors
cd go_indexer && go build       # ✓ Indexer builds
```

### Documentation Quick Links

- **5-min tutorial:** `starter_program/QUICKSTART.md`
- **API reference:** `starter_program/README.md`
- **CPI patterns:** `starter_program/CROSS_PROGRAM.md`
- **Setup guide:** `SETUP_GUIDE.md`
- **Integration:** `INTEGRATION_GUIDE.md`

### Network Switching

```bash
# Localnet
solana config set --url localhost
# RPC: http://localhost:8899

# Devnet
solana config set --url devnet  
# RPC: https://api.devnet.solana.com

# Mainnet
solana config set --url mainnet-beta
# RPC: https://api.mainnet-beta.solana.com
```

### Program Instructions

**starter_program (18 total):**
- Config: initialize, initialize_config, update_config, toggle_pause
- Users: create_user_account, update_user_account, close_user_account  
- Tokens: create_mint, mint_tokens, transfer_tokens, burn_tokens
- CPI: transfer_sol, initialize_counter, increment_counter, add_to_counter, etc.

**counter_program (6 total):**
- initialize, increment, decrement, add, reset, increment_with_payment

### Testing Matrix

| Test Type | Command | Expected |
|-----------|---------|----------|
| Unit | (none) | N/A |
| Integration | `anchor test` | 27 passing |
| TypeScript | `pnpm run type-check` | No errors |
| Full Stack | `./test-full-stack.sh` | All ✓ |

### Metrics Summary

- **Programs:** 2 programs, 24 instructions
- **Tests:** 27 integration tests (100% pass)
- **Code:** ~8,000+ lines total
- **Docs:** ~4,000+ lines across 11 files
- **Components:** 8+ React components
- **Hooks:** 6+ custom hooks

### Help Resources

- Docs: Read all `*.md` files
- Logs: `solana logs` or `docker-compose logs`
- Debug: Check browser console
- Community: Solana/Anchor Discord

### Git Commands (Manual Step Required)

```bash
# First time only
rm -rf starter_program/.git
git add -A
git commit -m "Initial commit: Full-stack Solana starter"
git branch -M main
```

---

**🎯 TL;DR:** Start validator → Deploy programs → Run frontend → Test!

**📚 New here?** Read `SETUP_GUIDE.md` first.

**🐳 Use Docker?** Just run `docker-compose up -d`.

**✅ All working?** Visit http://localhost:3000/programs

---

*Quick reference for Solana Starter Program*  
*For detailed docs, see README.md and other guides*
