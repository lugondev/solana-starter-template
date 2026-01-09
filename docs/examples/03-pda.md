---
layout: default
title: 3. PDA (Program Derived Address)
parent: Solana by Example
nav_order: 3
---

# 3. PDA (Program Derived Address)

Learn how to create and use Program Derived Addresses for secure, deterministic account management.

---

## What is a PDA?

A **Program Derived Address (PDA)** is an account address that:
- Is derived deterministically from seeds + program ID
- Has **no private key** (only the program can sign)
- Enables programs to own and control accounts

**Key concept:** PDAs allow your program to "sign" transactions without needing a wallet.

---

## Creating a PDA Account

**Source:** [`instructions/user.rs`](../../starter_program/programs/starter_program/src/instructions/user.rs)

### Rust (Program Side)

```rust
use crate::constants::*;
use crate::state::*;
use anchor_lang::prelude::*;

#[derive(Accounts)]
pub struct CreateUserAccount<'info> {
    #[account(
        init,                                              // Create new account
        payer = authority,                                 // Who pays for rent
        space = UserAccount::LEN,                          // Account size
        seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()], // PDA seeds
        bump                                               // Auto-find bump
    )]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn create_user_account_handler(ctx: Context<CreateUserAccount>) -> Result<()> {
    let user = &mut ctx.accounts.user_account;
    let clock = Clock::get()?;
    
    user.authority = ctx.accounts.authority.key();
    user.points = 0;
    user.created_at = clock.unix_timestamp;
    user.updated_at = clock.unix_timestamp;
    user.bump = ctx.bumps.user_account;  // Store bump for later use

    msg!("User account created: {}", user.authority);
    Ok(())
}
```

### TypeScript (Client Side)

```typescript
import { PublicKey, SystemProgram } from "@solana/web3.js";
import { Program } from "@coral-xyz/anchor";

// Derive PDA address
const [userPda, bump] = PublicKey.findProgramAddressSync(
  [
    Buffer.from("user_account"), 
    user.publicKey.toBuffer()
  ],
  program.programId
);

console.log("User PDA:", userPda.toBase58());
console.log("Bump:", bump);

// Create user account
const tx = await program.methods
  .createUserAccount()
  .accounts({
    userAccount: userPda,
    authority: user.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([user])
  .rpc();

console.log("Transaction signature:", tx);
```

---

## Understanding Seeds and Bump

### Seeds

Seeds are byte arrays used to derive the PDA:

```rust
seeds = [
    SEED_USER_ACCOUNT,           // Static seed (b"user_account")
    authority.key().as_ref()     // Dynamic seed (user's pubkey)
]
```

**Common seed patterns:**

| Pattern | Example | Use Case |
|---------|---------|----------|
| Static only | `[b"config"]` | Singleton account |
| Static + Pubkey | `[b"user", user_key]` | User-specific account |
| Static + Multiple | `[b"vault", mint, owner]` | Token vault per mint+owner |
| Static + Number | `[b"nft", &id.to_le_bytes()]` | Numbered items |

### Bump Seed

The **bump** is a number (0-255) that ensures the derived address is NOT on the ed25519 curve (no private key exists).

```rust
// Anchor automatically finds the canonical bump
#[account(
    seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
    bump  // Anchor finds bump automatically on init
)]
```

**Why store the bump?**
- Avoids recomputation on every transaction
- Slightly more efficient
- Canonical bump is always used

---

## Using Stored Bump

When interacting with existing PDAs, use the stored bump:

```rust
#[derive(Accounts)]
pub struct UpdateUserAccount<'info> {
    #[account(
        mut,
        seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
        bump = user_account.bump,  // Use stored bump (more efficient)
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub user_account: Account<'info, UserAccount>,

    pub authority: Signer<'info>,
}

pub fn update_user_account_handler(
    ctx: Context<UpdateUserAccount>,
    points: u64
) -> Result<()> {
    let user = &mut ctx.accounts.user_account;
    user.points = points;
    user.updated_at = Clock::get()?.unix_timestamp;
    
    msg!("Updated user {} to {} points", user.authority, points);
    Ok(())
}
```

---

## PDA as Signer

PDAs can "sign" transactions using `CpiContext::new_with_signer`:

**Source:** [`instructions/cpi.rs`](../../starter_program/programs/starter_program/src/instructions/cpi.rs)

```rust
use anchor_lang::system_program::{transfer, Transfer as SystemTransfer};

#[derive(Accounts)]
pub struct TransferSolWithPda<'info> {
    #[account(
        mut,
        seeds = [SEED_TOKEN_VAULT],
        bump
    )]
    pub vault: SystemAccount<'info>,

    #[account(mut)]
    /// CHECK: Recipient can be any account
    pub recipient: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}

pub fn transfer_sol_with_pda_handler(
    ctx: Context<TransferSolWithPda>,
    amount: u64
) -> Result<()> {
    // Create signer seeds for PDA
    let seeds = &[
        SEED_TOKEN_VAULT,
        &[ctx.bumps.vault]  // Include bump in seeds
    ];
    let signer = &[&seeds[..]];  // Double slice for CPI

    let cpi_accounts = SystemTransfer {
        from: ctx.accounts.vault.to_account_info(),
        to: ctx.accounts.recipient.to_account_info(),
    };

    let cpi_program = ctx.accounts.system_program.to_account_info();
    
    // Use new_with_signer for PDA signing
    let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

    transfer(cpi_ctx, amount)?;
    
    msg!("Transferred {} lamports from PDA vault", amount);
    Ok(())
}
```

### Key Points for PDA Signing

1. **Reconstruct seeds**: Use same seeds + bump
2. **Double slice**: `&[&seeds[..]]` for signer parameter
3. **Use `new_with_signer`**: Not `new()`

---

## Common PDA Patterns

### 1. Singleton Config

```rust
// Only one config per program
#[account(
    seeds = [b"config"],
    bump
)]
pub config: Account<'info, ProgramConfig>,
```

### 2. User Account

```rust
// One account per user
#[account(
    seeds = [b"user", user.key().as_ref()],
    bump
)]
pub user_account: Account<'info, UserAccount>,
```

### 3. Token Vault

```rust
// One vault per mint
#[account(
    seeds = [b"vault", mint.key().as_ref()],
    bump
)]
pub vault: SystemAccount<'info>,
```

### 4. Associated Account

```rust
// Account associated with two entities
#[account(
    seeds = [
        b"listing",
        nft_mint.key().as_ref(),
        seller.key().as_ref()
    ],
    bump
)]
pub listing: Account<'info, NftListing>,
```

### 5. Numbered Sequence

```rust
// Sequential items (NFTs, orders, etc.)
#[account(
    seeds = [
        b"nft",
        collection.key().as_ref(),
        &token_id.to_le_bytes()
    ],
    bump
)]
pub nft: Account<'info, Nft>,
```

---

## PDA Best Practices

✅ **Always store bump** - Saves computation  
✅ **Use constants for seeds** - Avoid typos  
✅ **Make seeds unique** - Prevent collisions  
✅ **Keep seeds simple** - Easier to derive client-side  
✅ **Document seed patterns** - Help future developers  

❌ **Don't use variable-length seeds** - Can cause derivation issues  
❌ **Don't reuse seed patterns** - Each PDA type should be unique  
❌ **Don't forget bump in signer seeds** - CPI will fail  

---

## Client-Side PDA Derivation

### Synchronous (Recommended)

```typescript
const [pda, bump] = PublicKey.findProgramAddressSync(
  [Buffer.from("user_account"), userKey.toBuffer()],
  programId
);
```

### Asynchronous

```typescript
const [pda, bump] = await PublicKey.findProgramAddress(
  [Buffer.from("user_account"), userKey.toBuffer()],
  programId
);
```

### With Multiple Seeds

```typescript
import { BN } from "@coral-xyz/anchor";

const tokenId = new BN(42);

const [nftPda] = PublicKey.findProgramAddressSync(
  [
    Buffer.from("nft"),
    collectionKey.toBuffer(),
    tokenId.toArrayLike(Buffer, "le", 8)  // u64 as little-endian
  ],
  programId
);
```

---

## Debugging PDAs

### Check if address is a PDA

```typescript
import { PublicKey } from "@solana/web3.js";

const isPda = !PublicKey.isOnCurve(address.toBuffer());
console.log("Is PDA:", isPda);
```

### Verify seeds match

```rust
// In program
require_keys_eq!(
    user_account.key(),
    Pubkey::find_program_address(
        &[SEED_USER_ACCOUNT, authority.key().as_ref()],
        ctx.program_id
    ).0,
    ErrorCode::InvalidPda
);
```

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Seeds constraint violated" | Wrong seeds provided | Check seed order and values |
| "Address not on curve" | Using non-PDA as PDA | Derive PDA correctly |
| "Invalid bump" | Wrong bump value | Use stored bump or let Anchor find it |
| "Cross-program invocation with unauthorized signer" | Missing PDA signer seeds | Include bump in signer seeds |

---

**Next:** [Account Constraints]({% link examples/04-constraints.md %}) →
