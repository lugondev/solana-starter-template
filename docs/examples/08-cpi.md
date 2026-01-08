---
layout: default
title: 8. Cross-Program Invocation (CPI)
parent: Solana by Example
nav_order: 8
---

# 8. Cross-Program Invocation (CPI)

Learn how to call other programs from your program - Solana's version of smart contract composability.

**Sources:**
- [`instructions/cpi.rs`](../../starter_program/programs/starter_program/src/instructions/cpi.rs)
- [`instructions/cross_program.rs`](../../starter_program/programs/starter_program/src/instructions/cross_program.rs)
- [`programs/counter_program/src/lib.rs`](../../starter_program/programs/counter_program/src/lib.rs)

---

## What is CPI?

**Cross-Program Invocation (CPI)** allows one program to call instructions on another program. This enables:

- 🔗 **Composability** - Build on top of existing programs
- 🏦 **DeFi protocols** - Swap, lend, borrow across programs
- 🎨 **NFT marketplaces** - Transfer NFTs owned by programs
- 💰 **Payment flows** - Programs can pay fees to other programs

---

## Basic CPI

### Caller Program (starter_program)

```rust
use counter_program::{
    cpi::accounts::Increment,
    program::CounterProgram,
    Counter,
};

#[derive(Accounts)]
pub struct IncrementCounter<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,

    pub authority: Signer<'info>,

    pub counter_program: Program<'info, CounterProgram>,
}

pub fn increment_counter_handler(ctx: Context<IncrementCounter>) -> Result<()> {
    // 1. Build CPI accounts
    let cpi_accounts = Increment {
        counter: ctx.accounts.counter.to_account_info(),
    };

    // 2. Get program to call
    let cpi_program = ctx.accounts.counter_program.to_account_info();
    
    // 3. Create CPI context
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    // 4. Make CPI call
    counter_program::cpi::increment(cpi_ctx)?;

    msg!("Counter incremented via CPI");
    Ok(())
}
```

### Add Program Dependency

In `Cargo.toml`:

```toml
[dependencies]
anchor-lang = "0.31.1"
counter-program = { path = "../counter_program", features = ["cpi"] }
```

**Important:** Add `features = ["cpi"]` to enable CPI module.

### Client-Side (TypeScript)

```typescript
const counterProgram = anchor.workspace.CounterProgram;

const [counterPda] = PublicKey.findProgramAddressSync(
  [Buffer.from("counter"), user.publicKey.toBuffer()],
  counterProgram.programId
);

await program.methods
  .incrementCounter()
  .accounts({
    counter: counterPda,
    authority: user.publicKey,
    counterProgram: counterProgram.programId,
  })
  .rpc();
```

---

## CPI with Arguments

Pass arguments to the called instruction:

```rust
#[derive(Accounts)]
pub struct AddToCounter<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,

    pub authority: Signer<'info>,

    pub counter_program: Program<'info, CounterProgram>,
}

pub fn add_to_counter_handler(ctx: Context<AddToCounter>, value: u64) -> Result<()> {
    let cpi_accounts = Add {
        counter: ctx.accounts.counter.to_account_info(),
    };

    let cpi_program = ctx.accounts.counter_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    // Pass argument to CPI
    counter_program::cpi::add(cpi_ctx, value)?;

    msg!("Added {} to counter via CPI", value);
    Ok(())
}
```

---

## CPI with PDA Signer

Allow your PDA to sign CPI calls:

```rust
use anchor_lang::system_program::{transfer, Transfer};

#[derive(Accounts)]
pub struct IncrementWithPaymentFromPda<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,

    #[account(
        mut,
        seeds = [SEED_TOKEN_VAULT],
        bump
    )]
    pub pda_vault: SystemAccount<'info>,

    #[account(mut)]
    /// CHECK: Fee collector
    pub fee_collector: AccountInfo<'info>,

    pub counter_program: Program<'info, CounterProgram>,
    pub system_program: Program<'info, System>,
}

pub fn increment_with_payment_from_pda_handler(
    ctx: Context<IncrementWithPaymentFromPda>,
    payment: u64,
) -> Result<()> {
    // Create PDA signer seeds
    let seeds = &[SEED_TOKEN_VAULT, &[ctx.bumps.pda_vault]];
    let signer = &[&seeds[..]];

    let cpi_accounts = IncrementWithPayment {
        counter: ctx.accounts.counter.to_account_info(),
        payer: ctx.accounts.pda_vault.to_account_info(),  // PDA pays
        fee_collector: ctx.accounts.fee_collector.to_account_info(),
        system_program: ctx.accounts.system_program.to_account_info(),
    };

    let cpi_program = ctx.accounts.counter_program.to_account_info();
    
    // Use new_with_signer for PDA signing
    let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

    counter_program::cpi::increment_with_payment(cpi_ctx, payment)?;

    msg!("Counter incremented with payment from PDA");
    Ok(())
}
```

### Key Difference

```rust
// Regular CPI (user signs)
CpiContext::new(program, accounts)

// CPI with PDA signer (PDA signs)
CpiContext::new_with_signer(program, accounts, signer_seeds)
```

---

## Multiple CPI Calls

Execute multiple CPIs in one instruction:

```rust
pub fn increment_multiple_handler(ctx: Context<IncrementMultiple>, times: u8) -> Result<()> {
    for i in 0..times {
        let cpi_accounts = Increment {
            counter: ctx.accounts.counter.to_account_info(),
        };

        let cpi_program = ctx.accounts.counter_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        counter_program::cpi::increment(cpi_ctx)?;
        msg!("Increment #{}", i + 1);
    }

    msg!("Incremented counter {} times", times);
    Ok(())
}
```

---

## CPI to System Program

Transfer SOL using system program:

```rust
use anchor_lang::system_program::{transfer, Transfer};

pub fn transfer_sol_handler(
    ctx: Context<TransferSol>,
    amount: u64
) -> Result<()> {
    let cpi_accounts = Transfer {
        from: ctx.accounts.from.to_account_info(),
        to: ctx.accounts.to.to_account_info(),
    };

    let cpi_program = ctx.accounts.system_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    transfer(cpi_ctx, amount)?;

    msg!("Transferred {} lamports", amount);
    Ok(())
}
```

---

## CPI to Token Program

Mint tokens via CPI:

```rust
use anchor_spl::token_interface::{mint_to, MintTo};

pub fn mint_via_cpi_handler(
    ctx: Context<MintViaCpi>,
    amount: u64
) -> Result<()> {
    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_MINT_AUTHORITY,
        &[ctx.bumps.mint_authority]
    ]];

    let cpi_accounts = MintTo {
        mint: ctx.accounts.mint.to_account_info(),
        to: ctx.accounts.token_account.to_account_info(),
        authority: ctx.accounts.mint_authority.to_account_info(),
    };

    let cpi_ctx = CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts,
        signer_seeds,
    );

    mint_to(cpi_ctx, amount)?;

    msg!("Minted {} tokens via CPI", amount);
    Ok(())
}
```

---

## Return Values from CPI

Anchor 0.30+ supports returning values from CPI:

### Callee Program (counter_program)

```rust
pub fn get_count(ctx: Context<GetCount>) -> Result<u64> {
    Ok(ctx.accounts.counter.count)
}
```

### Caller Program

```rust
pub fn read_counter_via_cpi_handler(ctx: Context<ReadCounterViaCpi>) -> Result<()> {
    let cpi_accounts = GetCount {
        counter: ctx.accounts.counter.to_account_info(),
    };

    let cpi_program = ctx.accounts.counter_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    // Get return value
    let count = counter_program::cpi::get_count(cpi_ctx)?.get();

    msg!("Counter value from CPI: {}", count);
    Ok(())
}
```

---

## CPI Security Considerations

### ✅ Do

1. **Validate program ID**
```rust
require_keys_eq!(
    ctx.accounts.counter_program.key(),
    EXPECTED_PROGRAM_ID,
    ErrorCode::InvalidProgram
);
```

2. **Check account ownership**
```rust
require_keys_eq!(
    ctx.accounts.counter.owner,
    ctx.accounts.counter_program.key(),
    ErrorCode::InvalidAccountOwner
);
```

3. **Validate signer seeds**
```rust
let expected_address = Pubkey::find_program_address(
    &[SEED_TOKEN_VAULT],
    ctx.program_id
).0;

require_keys_eq!(
    ctx.accounts.pda_vault.key(),
    expected_address,
    ErrorCode::InvalidPda
);
```

### ❌ Don't

- Call untrusted programs
- Skip account validation
- Assume CPI always succeeds (handle errors)
- Forget to check account ownership

---

## CPI Call Depth

Solana allows up to **4 levels** of CPI depth:

```
User -> ProgramA -> ProgramB -> ProgramC -> ProgramD (max depth)
```

Each CPI consumes compute units. Deep call chains can hit compute limits.

---

## Common CPI Patterns

### Pattern 1: Token Transfer with Fee

```rust
pub fn transfer_with_fee_handler(
    ctx: Context<TransferWithFee>,
    amount: u64,
    fee_bps: u64,
) -> Result<()> {
    let fee = amount
        .checked_mul(fee_bps)
        .ok_or(ErrorCode::ArithmeticOverflow)?
        .checked_div(10000)
        .ok_or(ErrorCode::ArithmeticOverflow)?;
    
    let amount_after_fee = amount
        .checked_sub(fee)
        .ok_or(ErrorCode::InsufficientBalance)?;

    // Transfer main amount
    transfer_checked(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            TransferChecked {
                from: ctx.accounts.from.to_account_info(),
                to: ctx.accounts.to.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
                mint: ctx.accounts.mint.to_account_info(),
            },
        ),
        amount_after_fee,
        ctx.accounts.mint.decimals,
    )?;

    // Transfer fee
    transfer_checked(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            TransferChecked {
                from: ctx.accounts.from.to_account_info(),
                to: ctx.accounts.fee_account.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
                mint: ctx.accounts.mint.to_account_info(),
            },
        ),
        fee,
        ctx.accounts.mint.decimals,
    )?;

    Ok(())
}
```

### Pattern 2: Conditional CPI

```rust
pub fn conditional_operation_handler(
    ctx: Context<ConditionalOperation>,
    should_increment: bool,
) -> Result<()> {
    if should_increment {
        let cpi_ctx = CpiContext::new(
            ctx.accounts.counter_program.to_account_info(),
            Increment {
                counter: ctx.accounts.counter.to_account_info(),
            },
        );
        
        counter_program::cpi::increment(cpi_ctx)?;
    }

    Ok(())
}
```

---

## Testing CPI

```typescript
describe("CPI Tests", () => {
  it("Should increment counter via CPI", async () => {
    const counterProgram = anchor.workspace.CounterProgram;
    
    // Get initial count
    const before = await counterProgram.account.counter.fetch(counterPda);
    const initialCount = before.count.toNumber();

    // Call via CPI
    await program.methods
      .incrementCounter()
      .accounts({
        counter: counterPda,
        authority: user.publicKey,
        counterProgram: counterProgram.programId,
      })
      .rpc();

    // Verify increment
    const after = await counterProgram.account.counter.fetch(counterPda);
    expect(after.count.toNumber()).to.equal(initialCount + 1);
  });

  it("Should fail with invalid program", async () => {
    const wrongProgram = Keypair.generate().publicKey;

    try {
      await program.methods
        .incrementCounter()
        .accounts({
          counter: counterPda,
          authority: user.publicKey,
          counterProgram: wrongProgram,  // Wrong program
        })
        .rpc();
      
      expect.fail("Should have failed");
    } catch (error) {
      expect(error).to.exist;
    }
  });
});
```

---

## Best Practices

✅ **Validate all CPI targets** - Check program IDs  
✅ **Handle CPI errors** - CPIs can fail  
✅ **Use typed CPIs** - Safer than raw invokes  
✅ **Check account ownership** - Prevent fake accounts  
✅ **Limit CPI depth** - Avoid hitting limits  
✅ **Test CPI paths** - Integration tests required  

❌ **Don't trust untrusted programs**  
❌ **Don't skip validation**  
❌ **Don't nest too deep** (max 4 levels)  
❌ **Don't ignore return values**  

---

**Next:** [Role-Based Access Control](09-rbac.md) →
