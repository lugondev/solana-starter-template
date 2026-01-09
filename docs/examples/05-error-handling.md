---
layout: default
title: 5. Error Handling
parent: Solana by Example
nav_order: 5
---

# 5. Error Handling

Learn how to define and use custom errors for better debugging and user experience.

---

## Define Custom Errors

**Source:** [`error.rs`](../../starter_program/programs/starter_program/src/error.rs)

```rust
use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Unauthorized access")]
    Unauthorized,

    #[msg("Invalid amount provided")]
    InvalidAmount,

    #[msg("Arithmetic overflow occurred")]
    ArithmeticOverflow,

    #[msg("Account is not rent exempt")]
    NotRentExempt,

    #[msg("Invalid state transition")]
    InvalidStateTransition,

    #[msg("CPI call failed")]
    CpiFailed,

    #[msg("Invalid mint address")]
    InvalidMint,

    #[msg("Invalid token account")]
    InvalidTokenAccount,

    #[msg("Insufficient balance")]
    InsufficientBalance,

    #[msg("Program is paused")]
    ProgramPaused,

    #[msg("Insufficient permissions for this action")]
    InsufficientPermissions,

    #[msg("Role already exists")]
    RoleAlreadyExists,

    #[msg("Role not found")]
    RoleNotFound,
}
```

### Error Code Numbers

Anchor assigns error codes automatically:
- First error = `6000`
- Second error = `6001`
- Third error = `6002`
- etc.

```rust
// Unauthorized = 6000
// InvalidAmount = 6001
// ArithmeticOverflow = 6002
```

---

## Using Errors in Programs

### 1. `require!` Macro

Most common pattern for validation:

```rust
use crate::error::ErrorCode;

pub fn deposit_to_treasury_handler(
    ctx: Context<DepositToTreasury>,
    amount: u64
) -> Result<()> {
    let treasury = &mut ctx.accounts.treasury;
    
    // Validate amount
    require!(amount > 0, ErrorCode::InvalidAmount);
    
    // Check circuit breaker
    require!(
        !treasury.circuit_breaker_active,
        ErrorCode::ProgramPaused
    );
    
    // Check balance
    require!(
        ctx.accounts.depositor.lamports() >= amount,
        ErrorCode::InsufficientBalance
    );

    // ... proceed with deposit logic
    Ok(())
}
```

**Syntax:**
```rust
require!(<boolean_condition>, ErrorCode::YourError);
```

### 2. `require_eq!` / `require_neq!`

For equality checks:

```rust
// Check equality
require_eq!(
    user_account.owner,
    ctx.accounts.signer.key(),
    ErrorCode::Unauthorized
);

// Check inequality
require_neq!(
    amount,
    0,
    ErrorCode::InvalidAmount
);
```

### 3. `require_keys_eq!` / `require_keys_neq!`

For Pubkey comparisons:

```rust
// Check pubkeys match
require_keys_eq!(
    config.admin,
    ctx.accounts.signer.key(),
    ErrorCode::Unauthorized
);

// Check pubkeys don't match
require_keys_neq!(
    sender.key(),
    recipient.key(),
    ErrorCode::InvalidRecipient
);
```

### 4. `require_gt!` / `require_gte!`

For numeric comparisons:

```rust
// Greater than
require_gt!(amount, 0, ErrorCode::InvalidAmount);

// Greater than or equal
require_gte!(
    user.balance,
    withdrawal_amount,
    ErrorCode::InsufficientBalance
);
```

---

## Errors in Constraints

Use errors directly in account constraints:

```rust
#[derive(Accounts)]
pub struct UpdateConfig<'info> {
    #[account(
        mut,
        seeds = [SEED_PROGRAM_CONFIG],
        bump = config.bump,
        has_one = admin @ ErrorCode::Unauthorized,  // Custom error
        constraint = !config.paused @ ErrorCode::ProgramPaused
    )]
    pub config: Account<'info, ProgramConfig>,

    pub admin: Signer<'info>,
}
```

---

## Safe Arithmetic with Errors

Prevent integer overflow/underflow:

```rust
pub fn update_balance_handler(
    ctx: Context<UpdateBalance>,
    amount: u64
) -> Result<()> {
    let account = &mut ctx.accounts.user_account;
    
    // ❌ Unsafe - can overflow
    // account.balance = account.balance + amount;
    
    // ✅ Safe - returns error on overflow
    account.balance = account
        .balance
        .checked_add(amount)
        .ok_or(ErrorCode::ArithmeticOverflow)?;
    
    Ok(())
}
```

### Safe Arithmetic Methods

```rust
// Addition
let result = a.checked_add(b).ok_or(ErrorCode::ArithmeticOverflow)?;

// Subtraction
let result = a.checked_sub(b).ok_or(ErrorCode::ArithmeticOverflow)?;

// Multiplication
let result = a.checked_mul(b).ok_or(ErrorCode::ArithmeticOverflow)?;

// Division
let result = a.checked_div(b).ok_or(ErrorCode::DivisionByZero)?;
```

---

## Error Handling Patterns

### Pattern 1: Early Return

```rust
pub fn process_payment_handler(
    ctx: Context<ProcessPayment>,
    amount: u64
) -> Result<()> {
    // Validate all inputs first
    require!(amount > 0, ErrorCode::InvalidAmount);
    require!(!ctx.accounts.config.paused, ErrorCode::ProgramPaused);
    require!(
        ctx.accounts.payer.lamports() >= amount,
        ErrorCode::InsufficientBalance
    );
    
    // All validations passed, proceed with logic
    // ...
    
    Ok(())
}
```

### Pattern 2: Custom Validation Functions

```rust
impl UserAccount {
    pub fn validate_permissions(&self, required_permission: u8) -> Result<()> {
        require!(
            self.has_permission(required_permission),
            ErrorCode::InsufficientPermissions
        );
        Ok(())
    }
}

pub fn restricted_action_handler(ctx: Context<RestrictedAction>) -> Result<()> {
    // Use helper function
    ctx.accounts.user_account.validate_permissions(MANAGE_TOKENS)?;
    
    // Proceed if validation passed
    // ...
    Ok(())
}
```

### Pattern 3: Result Propagation

```rust
pub fn complex_operation_handler(ctx: Context<ComplexOperation>) -> Result<()> {
    // Call helper that might fail
    validate_state(&ctx.accounts.config)?;
    process_transaction(&ctx.accounts)?;
    update_metrics(&mut ctx.accounts.metrics)?;
    
    Ok(())
}

fn validate_state(config: &ProgramConfig) -> Result<()> {
    require!(!config.paused, ErrorCode::ProgramPaused);
    require!(config.is_initialized, ErrorCode::NotInitialized);
    Ok(())
}
```

---

## Client-Side Error Handling

### TypeScript

```typescript
import { AnchorError } from "@coral-xyz/anchor";

try {
  await program.methods
    .updateConfig(newFee)
    .accounts({
      programConfig: configPda,
      admin: admin.publicKey,
    })
    .rpc();
    
  console.log("Config updated successfully");
  
} catch (error) {
  if (error instanceof AnchorError) {
    console.log("Error code:", error.error.errorCode.code);
    console.log("Error number:", error.error.errorCode.number);
    console.log("Error message:", error.error.errorMessage);
    
    // Handle specific errors
    switch (error.error.errorCode.code) {
      case "Unauthorized":
        console.error("You don't have permission to update config");
        break;
      case "ProgramPaused":
        console.error("Program is currently paused");
        break;
      case "InvalidAmount":
        console.error("Invalid fee amount provided");
        break;
      default:
        console.error("Unknown error:", error.error.errorMessage);
    }
  } else {
    console.error("Non-Anchor error:", error);
  }
}
```

### Parse Error Logs

```typescript
try {
  await program.methods.myInstruction().rpc();
} catch (error) {
  // Error logs contain detailed information
  console.log("Error logs:", error.logs);
  
  // Example log:
  // Program log: AnchorError thrown in programs/my_program/src/lib.rs:42:5
  // Program log: Error Code: InvalidAmount
  // Program log: Error Message: Invalid amount provided
}
```

---

## Best Practices

### ✅ Do

- **Use descriptive error messages** - Help users understand what went wrong
- **Validate early** - Check all inputs before modifying state
- **Use safe arithmetic** - Always use `checked_*` methods
- **Specific errors** - Create specific error codes for different failure cases
- **Document errors** - Explain when each error can occur

```rust
#[error_code]
pub enum ErrorCode {
    /// Thrown when the signer is not the program admin
    #[msg("Only the program admin can perform this action")]
    Unauthorized,
    
    /// Thrown when amount is zero or exceeds maximum
    #[msg("Amount must be between 1 and 1,000,000")]
    InvalidAmount,
}
```

### ❌ Don't

- **Generic errors** - Don't use one error for multiple cases
- **Silent failures** - Always return errors, never ignore them
- **Panic in production** - Use `Result<()>` instead of `panic!()`
- **Unclear messages** - "Error" is not helpful

```rust
// ❌ Bad
#[msg("Error")]
GeneralError,

// ✅ Good  
#[msg("Treasury balance insufficient for withdrawal")]
InsufficientTreasuryBalance,
```

---

## Common Error Patterns

### Ownership Validation

```rust
require_keys_eq!(
    user_account.owner,
    signer.key(),
    ErrorCode::NotAccountOwner
);
```

### Balance Checks

```rust
require_gte!(
    user.balance,
    amount,
    ErrorCode::InsufficientBalance
);
```

### State Validation

```rust
require!(
    !program.is_paused && program.is_initialized,
    ErrorCode::InvalidProgramState
);
```

### Time-based Validation

```rust
let clock = Clock::get()?;
require!(
    clock.unix_timestamp >= unlock_time,
    ErrorCode::StillLocked
);
```

### Permission Checks

```rust
require!(
    role.has_permission(MANAGE_TREASURY),
    ErrorCode::InsufficientPermissions
);
```

---

## Debugging Errors

### Enable Detailed Logs

In `Anchor.toml`:

```toml
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[scripts]
test = "yarn run ts-mocha -p ./tsconfig.json -t 1000000 tests/**/*.ts"

[programs.localnet]
my_program = "..."

[registry]
url = "https://api.apr.dev"

# Enable detailed error logs
[features]
seeds = true
resolution = true
```

### View Transaction Logs

```bash
solana confirm -v <transaction_signature>
```

### Test Specific Errors

```typescript
it("Should fail with InvalidAmount", async () => {
  try {
    await program.methods
      .deposit(new BN(0))  // Invalid amount
      .accounts({...})
      .rpc();
    
    expect.fail("Should have thrown error");
  } catch (error) {
    expect(error.error.errorCode.code).to.equal("InvalidAmount");
  }
});
```

---

**Next:** [Events]({% link examples/06-events.md %}) →
