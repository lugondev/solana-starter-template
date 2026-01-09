---
layout: default
title: 6. Events
parent: Solana by Example
nav_order: 6
---

# 6. Events

Learn how to emit and listen to program events for logging and real-time updates.

---

## What are Events?

Events allow your program to:
- **Log important actions** on-chain
- **Notify clients** in real-time
- **Track history** without storing everything in accounts
- **Trigger off-chain actions** (indexers, bots, UI updates)

Events are **cheap** (only cost transaction fees) and **efficient** (no account storage needed).

---

## Define Events

**Source:** [`events.rs`](../../starter_program/programs/starter_program/src/events.rs)

```rust
use anchor_lang::prelude::*;

#[event]
pub struct TokensMintedEvent {
    pub mint: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
    pub timestamp: i64,
}

#[event]
pub struct UserAccountCreatedEvent {
    pub user: Pubkey,
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct TreasuryDepositEvent {
    pub treasury: Pubkey,
    pub depositor: Pubkey,
    pub amount: u64,
    pub total_deposited: u64,
    pub timestamp: i64,
}

#[event]
pub struct RoleAssignedEvent {
    pub authority: Pubkey,
    pub role_type: RoleType,
    pub assigned_by: Pubkey,
    pub timestamp: i64,
}
```

### Event Anatomy

```rust
#[event]
pub struct MyEvent {
    pub field1: Type1,  // Any serializable type
    pub field2: Type2,
    // ... more fields
}
```

**Supported types:**
- Primitives: `u8`, `u64`, `i64`, `bool`, etc.
- `Pubkey`
- `String`
- Custom enums (with proper derives)
- Nested structs (with proper derives)

---

## Emit Events

Use the `emit!` macro to emit events:

**Source:** [`instructions/token.rs`](../../starter_program/programs/starter_program/src/instructions/token.rs)

```rust
use crate::events::*;

pub fn mint_tokens_handler(ctx: Context<MintTokens>, amount: u64) -> Result<()> {
    // Mint tokens logic...
    let cpi_accounts = MintTo {
        mint: ctx.accounts.mint.to_account_info(),
        to: ctx.accounts.token_account.to_account_info(),
        authority: ctx.accounts.mint_authority.to_account_info(),
    };

    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_MINT_AUTHORITY,
        &[ctx.bumps.mint_authority]
    ]];

    let cpi_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts
    ).with_signer(signer_seeds);

    token_interface::mint_to(cpi_ctx, amount)?;

    // Emit event after successful operation
    emit!(TokensMintedEvent {
        mint: ctx.accounts.mint.key(),
        recipient: ctx.accounts.token_account.key(),
        amount,
        timestamp: Clock::get()?.unix_timestamp,
    });

    msg!("Minted {} tokens", amount);
    Ok(())
}
```

### When to Emit Events

✅ **After successful operations** - State changes committed  
✅ **Before returning `Ok(())`** - Ensure operation completed  
✅ **Include relevant data** - All info needed by listeners  
✅ **Add timestamp** - Track when events occurred  

❌ **Don't emit before validation** - Event may be emitted then tx fails  
❌ **Don't emit sensitive data** - Events are public  
❌ **Don't emit too much** - Keep events focused  

---

## Event Examples

### User Account Creation

```rust
pub fn create_user_account_handler(ctx: Context<CreateUserAccount>) -> Result<()> {
    let user = &mut ctx.accounts.user_account;
    let clock = Clock::get()?;
    
    user.authority = ctx.accounts.authority.key();
    user.points = 0;
    user.created_at = clock.unix_timestamp;
    user.updated_at = clock.unix_timestamp;
    user.bump = ctx.bumps.user_account;

    emit!(UserAccountCreatedEvent {
        user: user.key(),
        authority: user.authority,
        timestamp: clock.unix_timestamp,
    });

    Ok(())
}
```

### Treasury Deposit

```rust
pub fn deposit_to_treasury_handler(
    ctx: Context<DepositToTreasury>,
    amount: u64
) -> Result<()> {
    let treasury = &mut ctx.accounts.treasury;
    
    // Transfer SOL
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

    // Update state
    treasury.total_deposited = treasury
        .total_deposited
        .checked_add(amount)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    // Emit event
    emit!(TreasuryDepositEvent {
        treasury: treasury.key(),
        depositor: ctx.accounts.depositor.key(),
        amount,
        total_deposited: treasury.total_deposited,
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
```

### Role Assignment

```rust
pub fn assign_role_handler(
    ctx: Context<AssignRole>,
    role_type: RoleType
) -> Result<()> {
    let role = &mut ctx.accounts.role;
    let clock = Clock::get()?;

    role.authority = ctx.accounts.target_authority.key();
    role.role_type = role_type;
    role.permissions = role_type.default_permissions();
    role.assigned_by = ctx.accounts.admin.key();
    role.assigned_at = clock.unix_timestamp;
    role.updated_at = clock.unix_timestamp;
    role.bump = ctx.bumps.role;

    emit!(RoleAssignedEvent {
        authority: role.authority,
        role_type,
        assigned_by: role.assigned_by,
        timestamp: clock.unix_timestamp,
    });

    Ok(())
}
```

---

## Listen to Events (Client-Side)

### TypeScript - Add Event Listener

```typescript
import { Program } from "@coral-xyz/anchor";
import { StarterProgram } from "../target/types/starter_program";

const program = anchor.workspace.StarterProgram as Program<StarterProgram>;

// Add event listener
const listener = program.addEventListener(
  "TokensMintedEvent",
  (event, slot) => {
    console.log("🎉 Tokens minted!");
    console.log("  Mint:", event.mint.toString());
    console.log("  Recipient:", event.recipient.toString());
    console.log("  Amount:", event.amount.toString());
    console.log("  Timestamp:", new Date(event.timestamp * 1000).toISOString());
    console.log("  Slot:", slot);
  }
);

// Keep listener active...

// Remove listener when done
await program.removeEventListener(listener);
```

### Multiple Event Listeners

```typescript
// Listen to multiple event types
const mintListener = program.addEventListener("TokensMintedEvent", (event) => {
  console.log("Tokens minted:", event.amount.toString());
});

const userListener = program.addEventListener("UserAccountCreatedEvent", (event) => {
  console.log("User created:", event.user.toString());
});

const depositListener = program.addEventListener("TreasuryDepositEvent", (event) => {
  console.log("Treasury deposit:", event.amount.toString());
});

// Clean up all listeners
await program.removeEventListener(mintListener);
await program.removeEventListener(userListener);
await program.removeEventListener(depositListener);
```

### Wait for Specific Event

```typescript
async function waitForMintEvent(expectedAmount: number): Promise<void> {
  return new Promise((resolve) => {
    const listener = program.addEventListener(
      "TokensMintedEvent",
      (event, slot) => {
        if (event.amount.toNumber() === expectedAmount) {
          console.log("Found matching mint event!");
          program.removeEventListener(listener);
          resolve();
        }
      }
    );
  });
}

// Use it
await program.methods.mintTokens(new BN(1000)).rpc();
await waitForMintEvent(1000);
console.log("Mint confirmed via event!");
```

---

## Event Filtering

### Filter by Field Value

```typescript
const listener = program.addEventListener(
  "TreasuryDepositEvent",
  (event, slot) => {
    // Only process large deposits
    if (event.amount.toNumber() >= 1_000_000) {
      console.log("Large deposit detected:", event.amount.toString());
      notifyAdmin(event);
    }
  }
);
```

### Filter by Multiple Conditions

```typescript
const listener = program.addEventListener(
  "RoleAssignedEvent",
  (event, slot) => {
    // Only admin role assignments by specific user
    if (
      event.roleType.admin &&
      event.assignedBy.equals(specificAdmin)
    ) {
      console.log("Admin role assigned by authorized user");
    }
  }
);
```

---

## Testing Events

### Assert Event Was Emitted

```typescript
import { expect } from "chai";

it("Should emit TokensMintedEvent", async () => {
  let eventEmitted = false;
  let eventData: any = null;

  const listener = program.addEventListener(
    "TokensMintedEvent",
    (event, slot) => {
      eventEmitted = true;
      eventData = event;
    }
  );

  // Execute instruction
  await program.methods
    .mintTokens(new BN(1000))
    .accounts({
      signer: user.publicKey,
      mint: mintPda,
      tokenAccount: userTokenAccount,
      mintAuthority: mintAuthority,
      tokenProgram: TOKEN_PROGRAM_ID,
      associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
      systemProgram: SystemProgram.programId,
    })
    .signers([user])
    .rpc();

  // Wait for event
  await new Promise((resolve) => setTimeout(resolve, 1000));

  // Verify event
  expect(eventEmitted).to.be.true;
  expect(eventData.amount.toNumber()).to.equal(1000);
  expect(eventData.mint.toString()).to.equal(mintPda.toString());

  await program.removeEventListener(listener);
});
```

### Test Event Data

```typescript
it("Should emit correct deposit event data", async () => {
  const depositAmount = 5_000_000; // 0.005 SOL
  let capturedEvent: any = null;

  const listener = program.addEventListener(
    "TreasuryDepositEvent",
    (event) => {
      capturedEvent = event;
    }
  );

  await program.methods
    .depositToTreasury(new BN(depositAmount))
    .accounts({...})
    .rpc();

  await new Promise((resolve) => setTimeout(resolve, 1000));

  expect(capturedEvent).to.not.be.null;
  expect(capturedEvent.amount.toNumber()).to.equal(depositAmount);
  expect(capturedEvent.depositor.toString()).to.equal(depositor.publicKey.toString());
  expect(capturedEvent.totalDeposited.toNumber()).to.be.greaterThan(0);

  await program.removeEventListener(listener);
});
```

---

## Best Practices

### ✅ Do

- **Include timestamps** - Makes events easier to track
- **Add context** - Include all relevant pubkeys and amounts
- **Emit after success** - Only emit when operation completes
- **Use descriptive names** - `TokensMintedEvent` not `Event1`
- **Keep events focused** - One event per significant action

### ❌ Don't

- **Emit before validation** - May emit then fail
- **Include sensitive data** - Events are public
- **Emit too frequently** - Each emit costs compute units
- **Forget to remove listeners** - Memory leaks in client

---

## Event vs Account Storage

| Use Case | Use Events | Use Accounts |
|----------|-----------|--------------|
| Notify clients | ✅ | ❌ |
| Historical logging | ✅ | ❌ |
| Temporary data | ✅ | ❌ |
| Query by indexer | ✅ | ✅ |
| Permanent storage | ❌ | ✅ |
| Complex queries | ❌ | ✅ |
| State that programs read | ❌ | ✅ |

**Rule of thumb:** Use events for notifications, use accounts for state.

---

## Advanced: Custom Event Parsing

```typescript
import { BorshCoder, EventParser } from "@coral-xyz/anchor";

// Parse events from transaction logs
const coder = new BorshCoder(program.idl);
const eventParser = new EventParser(program.programId, coder);

const tx = await connection.getTransaction(signature, {
  commitment: "confirmed",
});

const events = eventParser.parseLogs(tx.meta.logMessages);

for (let event of events) {
  console.log("Event:", event.name);
  console.log("Data:", event.data);
}
```

---

**Next:** [SPL Token Operations]({% link examples/07-spl-tokens.md %}) →
