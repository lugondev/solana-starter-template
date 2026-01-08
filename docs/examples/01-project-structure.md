---
layout: default
title: 1. Project Structure
parent: Solana by Example
nav_order: 1
---

# 1. Project Structure

Learn how to organize your Anchor program for maintainability and scalability.

---

## Anchor Program Layout

```
programs/starter_program/src/
├── lib.rs              # Program entry point, instruction definitions
├── constants.rs        # PDA seeds and constants
├── error.rs            # Custom error codes
├── events.rs           # Event definitions for logging
├── state/              # Account structures
│   ├── mod.rs
│   ├── config.rs
│   ├── user.rs
│   ├── role.rs
│   ├── treasury.rs
│   └── nft.rs
└── instructions/       # Instruction handlers
    ├── mod.rs
    ├── config.rs
    ├── user.rs
    ├── token.rs
    ├── cpi.rs
    ├── rbac.rs
    ├── treasury.rs
    └── nft.rs
```

> **Source:** [starter_program/programs/starter_program/src/](../../starter_program/programs/starter_program/src/)

---

## File Organization

### lib.rs - Program Entry Point

The main entry point defines your program ID and declares all instructions:

```rust
use anchor_lang::prelude::*;

declare_id!("gARh1g6reuvsAHB7DXqiuYzzyiJeoiJmtmCpV8Y5uWC");

#[program]
pub mod starter_program {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        instructions::config::initialize_handler(ctx)
    }

    pub fn create_user_account(ctx: Context<CreateUserAccount>) -> Result<()> {
        instructions::user::create_user_account_handler(ctx)
    }

    // ... more instructions
}
```

**Pattern:** Keep `lib.rs` minimal - only instruction declarations. Actual logic goes in `instructions/`.

### state/ - Account Structures

Each file defines one or more related account types:

```rust
// state/config.rs
#[account]
pub struct ProgramConfig {
    pub admin: Pubkey,
    pub fee_basis_points: u64,
    // ...
}

// state/user.rs
#[account]
pub struct UserAccount {
    pub authority: Pubkey,
    pub points: u64,
    // ...
}
```

**Pattern:** Group related state together. Keep state definitions separate from instruction logic.

### instructions/ - Instruction Handlers

Each file contains related instruction handlers:

```rust
// instructions/user.rs
pub fn create_user_account_handler(ctx: Context<CreateUserAccount>) -> Result<()> {
    // Implementation
}

pub fn update_user_account_handler(ctx: Context<UpdateUserAccount>) -> Result<()> {
    // Implementation
}
```

**Pattern:** Group instructions by domain (config, user, token, etc.).

---

## Constants Pattern

**Source:** [`constants.rs`](../../starter_program/programs/starter_program/src/constants.rs)

```rust
pub const SEED_PROGRAM_CONFIG: &[u8] = b"program_config";
pub const SEED_USER_ACCOUNT: &[u8] = b"user_account";
pub const SEED_TOKEN_VAULT: &[u8] = b"token_vault";
pub const SEED_MINT_AUTHORITY: &[u8] = b"mint_authority";
pub const SEED_ROLE: &[u8] = b"role";
pub const SEED_TREASURY: &[u8] = b"treasury";
pub const SEED_NFT_COLLECTION: &[u8] = b"nft_collection";
pub const SEED_NFT_METADATA: &[u8] = b"nft_metadata";
pub const SEED_NFT_LISTING: &[u8] = b"nft_listing";
pub const SEED_NFT_OFFER: &[u8] = b"nft_offer";
```

### Why Use Constants?

✅ **Prevents typos** in seed strings across multiple files  
✅ **Single source of truth** - change once, applies everywhere  
✅ **Easy to refactor** - rename with IDE support  
✅ **Better IDE support** - autocomplete and type checking  

### Usage Example

```rust
use crate::constants::*;

#[derive(Accounts)]
pub struct CreateUserAccount<'info> {
    #[account(
        init,
        payer = authority,
        space = UserAccount::LEN,
        seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
        bump
    )]
    pub user_account: Account<'info, UserAccount>,
    // ...
}
```

---

## Module Organization

### state/mod.rs

```rust
pub mod config;
pub mod user;
pub mod role;
pub mod treasury;
pub mod nft;

pub use config::*;
pub use user::*;
pub use role::*;
pub use treasury::*;
pub use nft::*;
```

### instructions/mod.rs

```rust
pub mod config;
pub mod user;
pub mod token;
pub mod cpi;
pub mod rbac;
pub mod treasury;
pub mod nft;

pub use config::*;
pub use user::*;
pub use token::*;
pub use cpi::*;
pub use rbac::*;
pub use treasury::*;
pub use nft::*;
```

**Pattern:** Re-export all public items from module root for easier imports.

---

## Best Practices

| Practice | Why |
|----------|-----|
| **Separate state from logic** | Keep `state/` and `instructions/` separate for clarity |
| **One responsibility per file** | `user.rs` handles user operations only |
| **Use constants for seeds** | Avoid magic strings, prevent typos |
| **Group related functionality** | Token operations together, CPI calls together |
| **Keep lib.rs minimal** | Just declarations, no business logic |

---

## Scaling Your Project

As your program grows:

1. **Split large files**: If `instructions/token.rs` gets too big, create `instructions/token/` with submodules
2. **Add utilities**: Create `utils/` for shared helpers
3. **Domain-driven structure**: Group by business domain, not technical layer

Example larger structure:

```
programs/starter_program/src/
├── lib.rs
├── constants.rs
├── error.rs
├── events.rs
├── utils/
│   ├── mod.rs
│   ├── math.rs
│   └── validation.rs
├── state/
│   ├── mod.rs
│   ├── config/
│   │   ├── mod.rs
│   │   ├── program_config.rs
│   │   └── fee_config.rs
│   └── user/
│       ├── mod.rs
│       ├── user_account.rs
│       └── user_stats.rs
└── instructions/
    └── ...
```

---

**Next:** [Account State Design](02-account-state.md) →
