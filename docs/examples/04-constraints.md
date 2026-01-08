---
layout: default
title: 4. Account Constraints
parent: Solana by Example
nav_order: 4
---

# 4. Account Constraints

Learn how to validate accounts and enforce security rules using Anchor's constraint system.

---

## Common Constraints

**Source:** [`instructions/config.rs`](../../starter_program/programs/starter_program/src/instructions/config.rs)

```rust
use anchor_lang::prelude::*;
use crate::{constants::*, state::*, error::ErrorCode};

#[derive(Accounts)]
pub struct UpdateConfig<'info> {
    #[account(
        mut,                                    // Account is mutable
        seeds = [SEED_PROGRAM_CONFIG],          // PDA seeds
        bump = program_config.bump,             // Use stored bump
        has_one = admin @ ErrorCode::Unauthorized  // Validate admin field
    )]
    pub program_config: Account<'info, ProgramConfig>,

    pub admin: Signer<'info>,  // Must sign transaction
}

pub fn update_config_handler(
    ctx: Context<UpdateConfig>,
    new_fee_destination: Pubkey,
    new_fee_basis_points: u64,
) -> Result<()> {
    let config = &mut ctx.accounts.program_config;
    config.fee_destination = new_fee_destination;
    config.fee_basis_points = new_fee_basis_points;
    
    msg!("Config updated by admin: {}", ctx.accounts.admin.key());
    Ok(())
}
```

### Constraint Breakdown

| Constraint | Purpose |
|------------|---------|
| `mut` | Account data can be modified |
| `seeds = [...]` | Validate PDA derivation |
| `bump = value` | Use stored bump seed |
| `has_one = field` | Validate field matches another account |

---

## Built-in Constraints

### 1. Mutability

```rust
#[account(mut)]  // Can modify account data
pub user_account: Account<'info, UserAccount>,

#[account(mut)]  // Can modify lamports (for rent, transfers)
pub payer: Signer<'info>,
```

### 2. Seeds Validation

```rust
#[account(
    seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
    bump = user_account.bump
)]
pub user_account: Account<'info, UserAccount>,
```

### 3. Field Validation (`has_one`)

```rust
// Validates: user_account.authority == authority.key()
#[account(
    has_one = authority @ ErrorCode::Unauthorized
)]
pub user_account: Account<'info, UserAccount>,

pub authority: Signer<'info>,
```

### 4. Owner Validation

```rust
// Ensures account is owned by specified program
#[account(
    owner = token_program.key()
)]
pub token_account: AccountInfo<'info>,

pub token_program: Program<'info, Token>,
```

---

## Custom Constraints

**Source:** [`instructions/treasury.rs`](../../starter_program/programs/starter_program/src/instructions/treasury.rs)

```rust
#[derive(Accounts)]
pub struct WithdrawFromTreasury<'info> {
    #[account(
        mut,
        seeds = [SEED_TREASURY],
        bump = treasury.bump,
        // Custom constraint: circuit breaker must be inactive
        constraint = !treasury.circuit_breaker_active @ ErrorCode::ProgramPaused
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        mut,
        // Custom constraint: signer must be admin
        constraint = authority.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub authority: Signer<'info>,

    #[account(mut)]
    /// CHECK: Destination for withdrawn funds
    pub destination: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}
```

### Constraint Syntax

```rust
constraint = <boolean_expression> @ ErrorCode::YourError
```

**Examples:**

```rust
// Simple comparison
constraint = amount > 0 @ ErrorCode::InvalidAmount

// Multiple conditions with &&
constraint = user.is_active && !user.is_banned @ ErrorCode::UserNotActive

// Range check
constraint = fee_bps <= 10000 @ ErrorCode::FeeTooHigh

// Access other accounts
constraint = signer.key() == config.admin @ ErrorCode::Unauthorized
```

---

## Account Lifecycle Constraints

### Init - Create New Account

```rust
#[account(
    init,                       // Create new account
    payer = payer,             // Who pays rent
    space = 8 + UserAccount::LEN,  // Size (discriminator + data)
    seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
    bump
)]
pub user_account: Account<'info, UserAccount>,

#[account(mut)]
pub payer: Signer<'info>,

pub system_program: Program<'info, System>,
```

**Required accounts for `init`:**
- `payer` (mutable signer)
- `system_program`

### Close - Delete Account and Reclaim Rent

**Source:** [`instructions/user.rs`](../../starter_program/programs/starter_program/src/instructions/user.rs)

```rust
#[derive(Accounts)]
pub struct CloseUserAccount<'info> {
    #[account(
        mut,
        close = authority,  // Close account, send rent to authority
        seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
        bump = user_account.bump,
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub authority: Signer<'info>,
}

pub fn close_user_account_handler(ctx: Context<CloseUserAccount>) -> Result<()> {
    // Account is automatically closed by Anchor
    // Rent is sent to 'authority'
    msg!("User account closed: {}", ctx.accounts.authority.key());
    Ok(())
}
```

### Realloc - Resize Account

```rust
#[account(
    mut,
    realloc = 8 + UserAccount::new_size(),
    realloc::payer = payer,
    realloc::zero = false,  // Don't zero out new space
    seeds = [SEED_USER_ACCOUNT, authority.key().as_ref()],
    bump = user_account.bump
)]
pub user_account: Account<'info, UserAccount>,

#[account(mut)]
pub payer: Signer<'info>,

pub system_program: Program<'info, System>,
```

---

## Init If Needed

Creates account if it doesn't exist, otherwise uses existing:

**Source:** [`instructions/token.rs`](../../starter_program/programs/starter_program/src/instructions/token.rs)

```rust
use anchor_spl::token_interface::{TokenAccount, Mint};

#[derive(Accounts)]
pub struct MintTokens<'info> {
    #[account(mut)]
    pub signer: Signer<'info>,

    #[account(
        init_if_needed,  // Create if doesn't exist, skip if exists
        payer = signer,
        associated_token::mint = mint,
        associated_token::authority = signer,
        associated_token::token_program = token_program,
    )]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    pub mint: InterfaceAccount<'info, Mint>,
    
    pub token_program: Interface<'info, TokenInterface>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}
```

**⚠️ Warning:** `init_if_needed` can be a security risk if not used carefully. Ensure proper validation.

---

## Token Account Constraints

### Associated Token Account

```rust
#[account(
    associated_token::mint = mint,
    associated_token::authority = owner,
    associated_token::token_program = token_program,
)]
pub token_account: InterfaceAccount<'info, TokenAccount>,
```

### Token Mint Constraints

```rust
#[account(
    init,
    payer = payer,
    mint::decimals = 6,
    mint::authority = mint_authority,
    mint::token_program = token_program,
    seeds = [b"mint"],
    bump
)]
pub mint: InterfaceAccount<'info, Mint>,
```

---

## Unsafe Accounts (`/// CHECK:`)

When using `AccountInfo` without type validation:

```rust
#[account(mut)]
/// CHECK: This account is validated manually in the instruction
pub arbitrary_account: AccountInfo<'info>,
```

**Always add `/// CHECK:` comment** explaining why it's safe.

### When to use:

- CPI targets that aren't typed
- Accounts with dynamic types
- System accounts (recipient addresses)

### Manual validation example:

```rust
// Validate owner
require_keys_eq!(
    arbitrary_account.owner,
    expected_program_id,
    ErrorCode::InvalidOwner
);

// Validate discriminator
let data = arbitrary_account.try_borrow_data()?;
require_eq!(
    &data[0..8],
    &UserAccount::discriminator(),
    ErrorCode::InvalidAccountType
);
```

---

## Constraint Combinations

### Full Example

```rust
#[derive(Accounts)]
pub struct ComplexInstruction<'info> {
    #[account(
        init,                                   // Lifecycle
        payer = payer,
        space = 8 + MyAccount::LEN,
        seeds = [b"my_account", owner.key().as_ref()],  // PDA
        bump,
        constraint = initial_value > 0 @ ErrorCode::InvalidValue  // Custom
    )]
    pub my_account: Account<'info, MyAccount>,

    #[account(
        mut,                                    // Mutability
        has_one = owner @ ErrorCode::Unauthorized,  // Field validation
        constraint = config.is_active @ ErrorCode::ConfigPaused  // Custom
    )]
    pub config: Account<'info, Config>,

    pub owner: Signer<'info>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub system_program: Program<'info, System>,
}
```

---

## Common Constraint Patterns

| Use Case | Constraint |
|----------|------------|
| **Admin-only** | `constraint = signer.key() == config.admin` |
| **Amount validation** | `constraint = amount > 0 && amount <= max` |
| **State check** | `constraint = !account.is_paused` |
| **Time-based** | `constraint = clock.unix_timestamp >= unlock_time` |
| **Whitelist** | `constraint = whitelist.contains(&user.key())` |
| **Balance check** | `constraint = account.lamports() >= min_balance` |

---

## Best Practices

✅ **Use `has_one`** when validating account fields  
✅ **Always specify error codes** with `@`  
✅ **Combine multiple constraints** for complex validation  
✅ **Document `/// CHECK:`** for unsafe accounts  
✅ **Validate early** - constraints run before instruction logic  
✅ **Use `constraint =`** for business logic validation  

❌ **Don't skip validation** - assume all inputs are malicious  
❌ **Don't use `init_if_needed`** without careful consideration  
❌ **Don't forget `mut`** on accounts you modify  

---

## Debugging Constraints

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "A seeds constraint was violated" | Wrong PDA seeds | Check seed values and order |
| "A has_one constraint was violated" | Field doesn't match account | Verify account relationships |
| "A raw constraint was violated" | Custom constraint failed | Check constraint logic |
| "Account not mutable" | Missing `mut` | Add `mut` to account |

### Testing Constraints

```typescript
// Test should fail with specific error
try {
  await program.methods
    .restrictedInstruction()
    .accounts({...})
    .rpc();
  
  expect.fail("Should have thrown Unauthorized error");
} catch (error) {
  expect(error.error.errorCode.code).to.equal("Unauthorized");
}
```

---

**Next:** [Error Handling](05-error-handling.md) →
