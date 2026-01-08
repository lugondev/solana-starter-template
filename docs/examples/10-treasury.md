---
layout: default
title: 10. Treasury Management
parent: Solana by Example
nav_order: 10
---

# 10. Treasury Management

Learn how to build a secure treasury system with deposits, withdrawals, and emergency controls.

**Sources:**
- [`state/treasury.rs`](../../starter_program/programs/starter_program/src/state/treasury.rs)
- [`instructions/treasury.rs`](../../starter_program/programs/starter_program/src/instructions/treasury.rs)

---

## Treasury State

```rust
#[account]
pub struct Treasury {
    pub authority: Pubkey,              // Admin who controls treasury
    pub total_deposited: u64,           // Total SOL deposited (lifetime)
    pub total_withdrawn: u64,           // Total SOL withdrawn (lifetime)
    pub emergency_mode: bool,           // Emergency withdrawal activated
    pub circuit_breaker_active: bool,   // Pause deposits/withdrawals
    pub created_at: i64,                // Creation timestamp
    pub bump: u8,                       // PDA bump
}

impl Treasury {
    pub const LEN: usize = 8 + 32 + 8 + 8 + 1 + 1 + 8 + 1;
    
    pub fn current_balance(&self) -> u64 {
        self.total_deposited
            .saturating_sub(self.total_withdrawn)
    }
}
```

---

## Initialize Treasury

```rust
#[derive(Accounts)]
pub struct InitializeTreasury<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + Treasury::LEN,
        seeds = [SEED_TREASURY],
        bump
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn initialize_treasury_handler(ctx: Context<InitializeTreasury>) -> Result<()> {
    let treasury = &mut ctx.accounts.treasury;
    let clock = Clock::get()?;

    treasury.authority = ctx.accounts.authority.key();
    treasury.total_deposited = 0;
    treasury.total_withdrawn = 0;
    treasury.emergency_mode = false;
    treasury.circuit_breaker_active = false;
    treasury.created_at = clock.unix_timestamp;
    treasury.bump = ctx.bumps.treasury;

    msg!("Treasury initialized");
    Ok(())
}
```

---

## Deposit to Treasury

```rust
use anchor_lang::system_program::{transfer, Transfer};

#[derive(Accounts)]
pub struct DepositToTreasury<'info> {
    #[account(
        mut,
        seeds = [SEED_TREASURY],
        bump = treasury.bump,
        constraint = !treasury.circuit_breaker_active @ ErrorCode::ProgramPaused
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(mut)]
    pub depositor: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn deposit_to_treasury_handler(
    ctx: Context<DepositToTreasury>,
    amount: u64
) -> Result<()> {
    require!(amount > 0, ErrorCode::InvalidAmount);
    require!(
        !ctx.accounts.treasury.circuit_breaker_active,
        ErrorCode::ProgramPaused
    );

    let treasury = &mut ctx.accounts.treasury;

    // Transfer SOL to treasury using CPI
    transfer(
        CpiContext::new(
            ctx.accounts.system_program.to_account_info(),
            Transfer {
                from: ctx.accounts.depositor.to_account_info(),
                to: treasury.to_account_info(),
            },
        ),
        amount,
    )?;

    // Update total deposited with overflow check
    treasury.total_deposited = treasury
        .total_deposited
        .checked_add(amount)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    emit!(TreasuryDepositEvent {
        treasury: treasury.key(),
        depositor: ctx.accounts.depositor.key(),
        amount,
        total_deposited: treasury.total_deposited,
        timestamp: Clock::get()?.unix_timestamp,
    });

    msg!("Deposited {} lamports to treasury", amount);
    Ok(())
}
```

---

## Withdraw from Treasury

### Method 1: Manual Lamport Transfer (Direct)

```rust
#[derive(Accounts)]
pub struct WithdrawFromTreasury<'info> {
    #[account(
        mut,
        seeds = [SEED_TREASURY],
        bump = treasury.bump,
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
        constraint = authority.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub authority: Signer<'info>,

    #[account(mut)]
    /// CHECK: Destination for withdrawn funds
    pub destination: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}

pub fn withdraw_from_treasury_handler(
    ctx: Context<WithdrawFromTreasury>,
    amount: u64,
) -> Result<()> {
    require!(amount > 0, ErrorCode::InvalidAmount);

    let treasury = &mut ctx.accounts.treasury;
    let treasury_balance = treasury.to_account_info().lamports();

    require!(treasury_balance >= amount, ErrorCode::InsufficientBalance);

    // Manual lamport transfer (no CPI needed)
    **treasury.to_account_info().try_borrow_mut_lamports()? -= amount;
    **ctx.accounts.destination.try_borrow_mut_lamports()? += amount;

    treasury.total_withdrawn = treasury
        .total_withdrawn
        .checked_add(amount)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    emit!(TreasuryWithdrawEvent {
        treasury: treasury.key(),
        recipient: ctx.accounts.destination.key(),
        amount,
        total_withdrawn: treasury.total_withdrawn,
        timestamp: Clock::get()?.unix_timestamp,
    });

    msg!("Withdrawn {} lamports from treasury", amount);
    Ok(())
}
```

**Why manual lamport transfer?**
- ✅ No CPI overhead
- ✅ More efficient (fewer compute units)
- ✅ Direct account manipulation

---

## Emergency Withdraw

Withdraw all funds minus rent-exempt minimum:

```rust
#[derive(Accounts)]
pub struct EmergencyWithdraw<'info> {
    #[account(
        mut,
        seeds = [SEED_TREASURY],
        bump = treasury.bump
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        mut,
        constraint = authority.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub authority: Signer<'info>,

    #[account(mut)]
    /// CHECK: Emergency destination
    pub destination: AccountInfo<'info>,
}

pub fn emergency_withdraw_handler(ctx: Context<EmergencyWithdraw>) -> Result<()> {
    let treasury = &mut ctx.accounts.treasury;
    let treasury_balance = treasury.to_account_info().lamports();

    // Keep rent-exempt minimum
    let rent = Rent::get()?;
    let rent_exempt_minimum = rent.minimum_balance(8 + Treasury::LEN);

    require!(
        treasury_balance > rent_exempt_minimum,
        ErrorCode::InsufficientBalance
    );

    // Calculate withdrawable amount
    let amount = treasury_balance
        .checked_sub(rent_exempt_minimum)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    // Transfer all except rent minimum
    **treasury.to_account_info().try_borrow_mut_lamports()? -= amount;
    **ctx.accounts.destination.try_borrow_mut_lamports()? += amount;

    // Set emergency mode flag
    treasury.emergency_mode = true;
    treasury.total_withdrawn = treasury
        .total_withdrawn
        .checked_add(amount)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    emit!(EmergencyWithdrawEvent {
        treasury: treasury.key(),
        recipient: ctx.accounts.destination.key(),
        amount,
        timestamp: Clock::get()?.unix_timestamp,
    });

    msg!("Emergency withdrawal: {} lamports", amount);
    Ok(())
}
```

---

## Circuit Breaker

Pause/unpause treasury operations:

```rust
#[derive(Accounts)]
pub struct ToggleCircuitBreaker<'info> {
    #[account(
        mut,
        seeds = [SEED_TREASURY],
        bump = treasury.bump
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        constraint = authority.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub authority: Signer<'info>,
}

pub fn toggle_circuit_breaker_handler(ctx: Context<ToggleCircuitBreaker>) -> Result<()> {
    let treasury = &mut ctx.accounts.treasury;
    treasury.circuit_breaker_active = !treasury.circuit_breaker_active;

    msg!(
        "Circuit breaker {}",
        if treasury.circuit_breaker_active {
            "activated"
        } else {
            "deactivated"
        }
    );
    
    Ok(())
}
```

---

## Query Treasury Balance

```rust
pub fn get_treasury_balance_handler(ctx: Context<GetTreasuryBalance>) -> Result<u64> {
    let treasury = &ctx.accounts.treasury;
    let balance = treasury.to_account_info().lamports();
    
    msg!("Treasury balance: {} lamports", balance);
    Ok(balance)
}
```

---

## Client-Side (TypeScript)

### Initialize Treasury

```typescript
const [treasuryPda] = PublicKey.findProgramAddressSync(
  [Buffer.from("treasury")],
  program.programId
);

await program.methods
  .initializeTreasury()
  .accounts({
    treasury: treasuryPda,
    authority: admin.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([admin])
  .rpc();
```

### Deposit

```typescript
const depositAmount = 5 * LAMPORTS_PER_SOL; // 5 SOL

await program.methods
  .depositToTreasury(new BN(depositAmount))
  .accounts({
    treasury: treasuryPda,
    depositor: user.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([user])
  .rpc();
```

### Withdraw

```typescript
const withdrawAmount = 1 * LAMPORTS_PER_SOL; // 1 SOL

await program.methods
  .withdrawFromTreasury(new BN(withdrawAmount))
  .accounts({
    treasury: treasuryPda,
    programConfig: configPda,
    authority: admin.publicKey,
    destination: recipient.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([admin])
  .rpc();
```

### Check Balance

```typescript
const treasury = await program.account.treasury.fetch(treasuryPda);
console.log("Total deposited:", treasury.totalDeposited.toNumber());
console.log("Total withdrawn:", treasury.totalWithdrawn.toNumber());
console.log("Current balance:", treasury.currentBalance());

// Or get actual lamports
const accountInfo = await connection.getAccountInfo(treasuryPda);
console.log("Actual balance:", accountInfo.lamports);
```

---

## Security Considerations

### ✅ Best Practices

1. **Admin-only withdrawals**
```rust
constraint = authority.key() == program_config.admin @ ErrorCode::Unauthorized
```

2. **Circuit breaker** - Pause in emergencies
```rust
constraint = !treasury.circuit_breaker_active @ ErrorCode::ProgramPaused
```

3. **Safe arithmetic**
```rust
treasury.total_deposited
    .checked_add(amount)
    .ok_or(ErrorCode::ArithmeticOverflow)?
```

4. **Preserve rent-exempt minimum**
```rust
let rent_exempt_minimum = rent.minimum_balance(8 + Treasury::LEN);
require!(balance > rent_exempt_minimum, ErrorCode::NotRentExempt);
```

5. **Emit events** - Audit trail
```rust
emit!(TreasuryDepositEvent { ... });
```

### ❌ Common Vulnerabilities

- Missing admin check → Anyone can withdraw
- No balance check → Underflow or close account
- No overflow check → Silent wrapping
- Skipping rent check → Account may close
- No pause mechanism → Can't stop attacks

---

## Advanced: Multi-sig Treasury

```rust
#[account]
pub struct Treasury {
    pub authorities: Vec<Pubkey>,  // Multiple admins
    pub threshold: u8,             // M-of-N signatures required
    pub pending_withdrawal: Option<PendingWithdrawal>,
    // ... other fields
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct PendingWithdrawal {
    pub amount: u64,
    pub destination: Pubkey,
    pub approvals: Vec<Pubkey>,
    pub created_at: i64,
    pub expires_at: i64,
}

impl Treasury {
    pub fn has_quorum(&self, approvals: &[Pubkey]) -> bool {
        approvals.len() as u8 >= self.threshold
    }
}
```

---

## Testing Treasury

```typescript
describe("Treasury", () => {
  it("Should deposit and withdraw", async () => {
    const depositAmount = 5 * LAMPORTS_PER_SOL;
    
    // Deposit
    await program.methods
      .depositToTreasury(new BN(depositAmount))
      .accounts({
        treasury: treasuryPda,
        depositor: user.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([user])
      .rpc();

    // Check balance
    const treasuryAccount = await connection.getAccountInfo(treasuryPda);
    expect(treasuryAccount.lamports).to.be.greaterThan(depositAmount);

    // Withdraw
    const withdrawAmount = 1 * LAMPORTS_PER_SOL;
    await program.methods
      .withdrawFromTreasury(new BN(withdrawAmount))
      .accounts({
        treasury: treasuryPda,
        programConfig: configPda,
        authority: admin.publicKey,
        destination: recipient.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([admin])
      .rpc();

    // Verify
    const treasury = await program.account.treasury.fetch(treasuryPda);
    expect(treasury.totalWithdrawn.toNumber()).to.equal(withdrawAmount);
  });
});
```

---

**Next:** [NFT Implementation](11-nft.md) →
