# Solana Starter Program

A comprehensive full-stack Solana development starter kit featuring Anchor programs and a modern Next.js frontend. Demonstrates all essential Solana patterns including PDAs, SPL tokens, cross-program invocations, RBAC, and real-time blockchain data fetching.

## Overview

This monorepo contains:

- **`starter_program/`** - Anchor workspace with two Solana programs (39+ integration tests)
- **`frontend/`** - Next.js 16.1.1 frontend with wallet integration and program interaction

## Features

### Anchor Programs

| Feature | Description |
|---------|-------------|
| Program Configuration | Admin-controlled config with pause functionality |
| PDA Patterns | User accounts with seeds-based derivation |
| SPL Token Operations | Mint, transfer, and burn tokens |
| Cross-Program Invocation | CPI examples with and without PDA signers |
| Inter-Program Communication | Counter program with bidirectional CPI patterns |
| Role-Based Access Control | Permission system with role assignment |
| Error Handling | Custom error codes with descriptive messages |

### Frontend

| Feature | Description |
|---------|-------------|
| Next.js 16.1.1 | App Router with React 19 |
| Wallet Integration | Phantom, Solflare, Torus support |
| Real-time Updates | WebSocket subscriptions for balance changes |
| Program Interaction | Full integration with Anchor programs |
| TypeScript Strict | Type-safe development |
| Tailwind CSS 4 | Modern styling |

## Quick Start

### Prerequisites

- Rust 1.70+
- Solana CLI 1.18+
- Anchor CLI 0.31.1
- Node.js 18+
- pnpm (for frontend)

### 1. Install Anchor

```bash
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install 0.31.1
avm use 0.31.1
```

### 2. Build & Test Programs

```bash
cd starter_program
yarn install
anchor build
anchor test
```

### 3. Run Frontend

```bash
cd frontend
pnpm install
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000)

## Project Structure

```
solana-starter-program/
├── starter_program/                 # Anchor workspace
│   ├── programs/
│   │   ├── starter_program/        # Main program (17 instructions)
│   │   │   └── src/
│   │   │       ├── lib.rs
│   │   │       ├── constants.rs
│   │   │       ├── error.rs
│   │   │       ├── state/          # Config, User, Role accounts
│   │   │       └── instructions/   # All instruction handlers
│   │   └── counter_program/        # Counter program (5 instructions)
│   ├── tests/
│   │   ├── starter_program.ts      # 25+ tests
│   │   ├── cross_program.ts        # 11 tests
│   │   └── rbac.ts                 # RBAC tests
│   ├── Anchor.toml
│   └── CROSS_PROGRAM.md            # CPI guide
│
└── frontend/                        # Next.js application
    ├── app/                         # App Router pages
    ├── components/
    │   ├── features/
    │   │   ├── wallet/             # Wallet components
    │   │   ├── starter/            # Starter program UI
    │   │   └── counter/            # Counter program UI
    │   └── ui/                     # Reusable components
    └── lib/
        ├── hooks/                  # Custom React hooks
        ├── anchor/                 # Program IDLs and types
        └── solana/                 # Connection config
```

## Programs

### Starter Program

**Program ID:** `gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC`

| Instruction | Description |
|-------------|-------------|
| `initialize` | Initialize program |
| `initialize_config` | Create program config |
| `update_config` | Update admin, fees |
| `toggle_pause` | Pause/unpause program |
| `create_user_account` | Create PDA user account |
| `update_user_account` | Update user points |
| `close_user_account` | Close and reclaim rent |
| `create_mint` | Create SPL token mint |
| `mint_tokens` | Mint tokens |
| `transfer_tokens` | Transfer tokens |
| `burn_tokens` | Burn tokens |
| `transfer_sol` | Transfer SOL via CPI |
| `transfer_sol_with_pda` | Transfer SOL from PDA |
| `transfer_tokens_with_pda` | Transfer tokens from PDA |
| `assign_role` | Assign role to user |
| `update_role_permissions` | Modify role permissions |
| `revoke_role` | Remove role from user |

### Counter Program

**Program ID:** `CounzVsCGF4VzNkAwePKC9mXr6YWiFYF4kLW6YdV8Cc`

| Instruction | Description |
|-------------|-------------|
| `initialize` | Create counter account |
| `increment` | Increment by 1 |
| `decrement` | Decrement by 1 |
| `add` | Add arbitrary value |
| `reset` | Reset to 0 (authority only) |
| `increment_with_payment` | Increment with SOL payment |

## Usage Examples

### Initialize Config

```typescript
const [configPda] = PublicKey.findProgramAddressSync(
  [Buffer.from('program_config')],
  program.programId
);

await program.methods
  .initializeConfig(feeDestination)
  .accounts({
    programConfig: configPda,
    authority: admin.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

### Create User Account (PDA)

```typescript
const [userPda] = PublicKey.findProgramAddressSync(
  [Buffer.from('user_account'), user.publicKey.toBuffer()],
  program.programId
);

await program.methods
  .createUserAccount()
  .accounts({
    userAccount: userPda,
    authority: user.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

### Cross-Program Invocation

```typescript
// Increment counter via CPI from starter_program
await program.methods
  .incrementCounter()
  .accounts({
    counter: counterPda,
    authority: user.publicKey,
    counterProgram: counterProgram.programId,
  })
  .rpc();
```

### Mint Tokens

```typescript
const userTokenAccount = await getAssociatedTokenAddress(
  mintPda,
  user.publicKey
);

await program.methods
  .mintTokens(new BN(1000000))
  .accounts({
    signer: user.publicKey,
    tokenAccount: userTokenAccount,
    mint: mintPda,
    mintAuthority: mintAuthority,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

## Frontend Hooks

```typescript
// Wallet balance with auto-refresh
const { balance, isLoading } = useBalance(publicKey, {
  refreshInterval: 30000,
});

// Send transaction with loading state
const { send, loading, error } = useSendTransaction({
  onSuccess: (sig) => console.log(sig),
});

// Program interactions
const { createUserAccount, updateUserAccount } = useStarterProgram();
const { increment, add, reset } = useCounterProgram();
```

## Testing

```bash
cd starter_program

# Run all tests
anchor test

# Run specific test file
anchor test tests/starter_program.ts
anchor test tests/cross_program.ts
anchor test tests/rbac.ts
```

**Test Coverage:** 39+ integration tests covering all program functionality.

## Network Configuration

### Programs (Anchor.toml)

```toml
[provider]
cluster = "localnet"  # Change to devnet/mainnet
wallet = "~/.config/solana/id.json"
```

### Frontend (.env.local)

```env
NEXT_PUBLIC_SOLANA_RPC_HOST=https://api.devnet.solana.com
NEXT_PUBLIC_SOLANA_NETWORK=devnet
```

## Security Features

- Account ownership validation
- Seeds validation for PDAs
- Bump seed storage and verification
- `has_one` constraints for authority checks
- Rent exemption enforcement
- Custom error codes with descriptive messages
- Role-based access control system

## Resources

- [Anchor Documentation](https://www.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Solana Developer Docs](https://solana.com/docs)
- [Wallet Adapter](https://github.com/solana-labs/wallet-adapter)

## License

MIT
