---
layout: default
title: 7. SPL Token Operations
parent: Solana by Example
nav_order: 7
---

# 7. SPL Token Operations

Learn how to create and manage SPL tokens (fungible tokens) on Solana.

**Source:** [`instructions/token.rs`](../../starter_program/programs/starter_program/src/instructions/token.rs)

---

## SPL Token Basics

SPL tokens are Solana's standard for fungible tokens. Key concepts:

- **Mint**: The token definition (like an ERC-20 contract)
- **Token Account**: Holds tokens for a specific owner
- **Associated Token Account (ATA)**: Deterministic token account address
- **Authority**: Can be a PDA (for program control) or wallet

---

## Create Mint with PDA Authority

```rust
use anchor_spl::token_interface::{Mint, TokenInterface};
use crate::constants::*;

#[derive(Accounts)]
pub struct CreateMint<'info> {
    #[account(mut)]
    pub signer: Signer<'info>,

    #[account(
        init,
        payer = signer,
        mint::decimals = 6,                    // Token decimals (like USDC)
        mint::authority = mint_authority,      // PDA as mint authority
        mint::token_program = token_program,
        seeds = [b"mint"],
        bump
    )]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        seeds = [SEED_MINT_AUTHORITY],
        bump
    )]
    /// CHECK: PDA used as mint authority
    pub mint_authority: UncheckedAccount<'info>,

    pub token_program: Interface<'info, TokenInterface>,
    pub system_program: Program<'info, System>,
}

pub fn create_mint_handler(ctx: Context<CreateMint>) -> Result<()> {
    msg!("Mint created with PDA authority");
    Ok(())
}
```

### Why PDA as Authority?

✅ **Program control** - Only your program can mint/burn  
✅ **No private key** - Cannot be stolen or lost  
✅ **Deterministic** - Same address every time  
✅ **Auditable** - All actions are on-chain  

---

## Mint Tokens

```rust
use anchor_spl::token_interface::{mint_to, MintTo, TokenAccount};

#[derive(Accounts)]
pub struct MintTokens<'info> {
    #[account(mut)]
    pub signer: Signer<'info>,

    #[account(
        init_if_needed,
        payer = signer,
        associated_token::mint = mint,
        associated_token::authority = signer,
        associated_token::token_program = token_program,
    )]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        seeds = [SEED_MINT_AUTHORITY],
        bump
    )]
    /// CHECK: PDA mint authority
    pub mint_authority: UncheckedAccount<'info>,

    pub token_program: Interface<'info, TokenInterface>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn mint_tokens_handler(ctx: Context<MintTokens>, amount: u64) -> Result<()> {
    // Create signer seeds for PDA
    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_MINT_AUTHORITY,
        &[ctx.bumps.mint_authority]
    ]];

    let cpi_accounts = MintTo {
        mint: ctx.accounts.mint.to_account_info(),
        to: ctx.accounts.token_account.to_account_info(),
        authority: ctx.accounts.mint_authority.to_account_info(),
    };

    let cpi_program = ctx.accounts.token_program.to_account_info();
    let cpi_context = CpiContext::new(cpi_program, cpi_accounts)
        .with_signer(signer_seeds);

    mint_to(cpi_context, amount)?;

    msg!("Minted {} tokens to {}", amount, ctx.accounts.token_account.key());
    Ok(())
}
```

### Client-Side (TypeScript)

```typescript
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID, ASSOCIATED_TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { BN } from "@coral-xyz/anchor";

const [mintPda] = PublicKey.findProgramAddressSync(
  [Buffer.from("mint")],
  program.programId
);

const [mintAuthority] = PublicKey.findProgramAddressSync(
  [Buffer.from("mint_authority")],
  program.programId
);

const userTokenAccount = await getAssociatedTokenAddress(
  mintPda,
  user.publicKey
);

await program.methods
  .mintTokens(new BN(1_000_000)) // 1 token with 6 decimals
  .accounts({
    signer: user.publicKey,
    tokenAccount: userTokenAccount,
    mint: mintPda,
    mintAuthority: mintAuthority,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
  })
  .signers([user])
  .rpc();
```

---

## Transfer Tokens

```rust
use anchor_spl::token_interface::{transfer_checked, TransferChecked};

#[derive(Accounts)]
pub struct TransferTokens<'info> {
    #[account(mut)]
    pub from_account: InterfaceAccount<'info, TokenAccount>,

    #[account(mut)]
    pub to_account: InterfaceAccount<'info, TokenAccount>,

    pub mint: InterfaceAccount<'info, Mint>,

    pub authority: Signer<'info>,

    pub token_program: Interface<'info, TokenInterface>,
}

pub fn transfer_tokens_handler(ctx: Context<TransferTokens>, amount: u64) -> Result<()> {
    let cpi_accounts = TransferChecked {
        from: ctx.accounts.from_account.to_account_info(),
        to: ctx.accounts.to_account.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
        mint: ctx.accounts.mint.to_account_info(),
    };

    let cpi_program = ctx.accounts.token_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    // transfer_checked validates decimals (safer than transfer)
    transfer_checked(
        cpi_ctx,
        amount,
        ctx.accounts.mint.decimals
    )?;

    msg!("Transferred {} tokens", amount);
    Ok(())
}
```

### Why `transfer_checked`?

✅ **Validates decimals** - Prevents precision errors  
✅ **Validates mint** - Ensures both accounts use same token  
✅ **Safer** - Recommended by Solana  

---

## Burn Tokens

```rust
use anchor_spl::token_interface::{burn, Burn};

#[derive(Accounts)]
pub struct BurnTokens<'info> {
    #[account(mut)]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    pub authority: Signer<'info>,

    pub token_program: Interface<'info, TokenInterface>,
}

pub fn burn_tokens_handler(ctx: Context<BurnTokens>, amount: u64) -> Result<()> {
    let cpi_accounts = Burn {
        mint: ctx.accounts.mint.to_account_info(),
        from: ctx.accounts.token_account.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };

    let cpi_program = ctx.accounts.token_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    burn(cpi_ctx, amount)?;

    msg!("Burned {} tokens", amount);
    Ok(())
}
```

---

## Delegate Approval

Allow another account to spend tokens on your behalf:

```rust
use anchor_spl::token_interface::{approve, Approve};

#[derive(Accounts)]
pub struct ApproveDelegate<'info> {
    #[account(mut)]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: Delegate can be any account
    pub delegate: AccountInfo<'info>,

    pub authority: Signer<'info>,

    pub token_program: Interface<'info, TokenInterface>,
}

pub fn approve_delegate_handler(ctx: Context<ApproveDelegate>, amount: u64) -> Result<()> {
    let cpi_accounts = Approve {
        to: ctx.accounts.token_account.to_account_info(),
        delegate: ctx.accounts.delegate.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };

    let cpi_program = ctx.accounts.token_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

    approve(cpi_ctx, amount)?;

    msg!("Approved {} tokens for delegate", amount);
    Ok(())
}
```

### Revoke Approval

```rust
use anchor_spl::token_interface::{revoke, Revoke};

pub fn revoke_delegate_handler(ctx: Context<RevokeDelegate>) -> Result<()> {
    let cpi_accounts = Revoke {
        source: ctx.accounts.token_account.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };

    let cpi_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts
    );

    revoke(cpi_ctx)?;

    msg!("Delegate approval revoked");
    Ok(())
}
```

---

## Freeze/Thaw Token Account

Prevent transfers (requires freeze authority):

```rust
use anchor_spl::token_interface::{freeze_account, FreezeAccount};

#[derive(Accounts)]
pub struct FreezeTokenAccount<'info> {
    #[account(mut)]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        seeds = [SEED_MINT_AUTHORITY],
        bump
    )]
    /// CHECK: Freeze authority PDA
    pub freeze_authority: UncheckedAccount<'info>,

    pub token_program: Interface<'info, TokenInterface>,
}

pub fn freeze_token_account_handler(ctx: Context<FreezeTokenAccount>) -> Result<()> {
    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_MINT_AUTHORITY,
        &[ctx.bumps.freeze_authority]
    ]];

    let cpi_accounts = FreezeAccount {
        account: ctx.accounts.token_account.to_account_info(),
        mint: ctx.accounts.mint.to_account_info(),
        authority: ctx.accounts.freeze_authority.to_account_info(),
    };

    let cpi_program = ctx.accounts.token_program.to_account_info();
    let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts)
        .with_signer(signer_seeds);

    freeze_account(cpi_ctx)?;

    msg!("Token account frozen");
    Ok(())
}
```

### Thaw (Unfreeze)

```rust
use anchor_spl::token_interface::{thaw_account, ThawAccount};

pub fn thaw_token_account_handler(ctx: Context<ThawTokenAccount>) -> Result<()> {
    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_MINT_AUTHORITY,
        &[ctx.bumps.freeze_authority]
    ]];

    let cpi_accounts = ThawAccount {
        account: ctx.accounts.token_account.to_account_info(),
        mint: ctx.accounts.mint.to_account_info(),
        authority: ctx.accounts.freeze_authority.to_account_info(),
    };

    let cpi_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts
    ).with_signer(signer_seeds);

    thaw_account(cpi_ctx)?;

    msg!("Token account thawed");
    Ok(())
}
```

---

## Close Token Account (Reclaim Rent)

```rust
use anchor_spl::token_interface::{close_account, CloseAccount};

#[derive(Accounts)]
pub struct CloseTokenAccount<'info> {
    #[account(mut)]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(mut)]
    pub destination: SystemAccount<'info>,

    pub authority: Signer<'info>,

    pub token_program: Interface<'info, TokenInterface>,
}

pub fn close_token_account_handler(ctx: Context<CloseTokenAccount>) -> Result<()> {
    // Ensure account is empty
    require_eq!(
        ctx.accounts.token_account.amount,
        0,
        ErrorCode::TokenAccountNotEmpty
    );

    let cpi_accounts = CloseAccount {
        account: ctx.accounts.token_account.to_account_info(),
        destination: ctx.accounts.destination.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };

    let cpi_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts
    );

    close_account(cpi_ctx)?;

    msg!("Token account closed, rent reclaimed");
    Ok(())
}
```

---

## Token Extensions (Token-2022)

Token-2022 supports extensions like:
- Transfer fees
- Transfer hooks
- Confidential transfers
- Interest-bearing tokens

```rust
use anchor_spl::token_2022::Token2022;

pub token_program: Program<'info, Token2022>,
```

---

## Complete Example: Token Swap

```rust
pub fn swap_tokens_handler(
    ctx: Context<SwapTokens>,
    amount_in: u64,
    minimum_amount_out: u64
) -> Result<()> {
    // 1. Transfer input tokens from user
    transfer_checked(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            TransferChecked {
                from: ctx.accounts.user_token_in.to_account_info(),
                to: ctx.accounts.pool_token_in.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
                mint: ctx.accounts.mint_in.to_account_info(),
            },
        ),
        amount_in,
        ctx.accounts.mint_in.decimals,
    )?;

    // 2. Calculate output amount (simplified)
    let amount_out = calculate_swap_output(amount_in, minimum_amount_out)?;

    // 3. Transfer output tokens to user (PDA signs)
    let signer_seeds: &[&[&[u8]]] = &[&[
        SEED_POOL_AUTHORITY,
        &[ctx.bumps.pool_authority]
    ]];

    transfer_checked(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            TransferChecked {
                from: ctx.accounts.pool_token_out.to_account_info(),
                to: ctx.accounts.user_token_out.to_account_info(),
                authority: ctx.accounts.pool_authority.to_account_info(),
                mint: ctx.accounts.mint_out.to_account_info(),
            },
            signer_seeds,
        ),
        amount_out,
        ctx.accounts.mint_out.decimals,
    )?;

    msg!("Swapped {} for {}", amount_in, amount_out);
    Ok(())
}
```

---

## Best Practices

✅ **Use `transfer_checked`** instead of `transfer`  
✅ **Use PDA as mint authority** for program control  
✅ **Store bump seeds** to avoid recomputation  
✅ **Validate token accounts** match expected mint  
✅ **Check balances** before transfers  
✅ **Use `init_if_needed` carefully** - security risk  

❌ **Don't hardcode decimals** - read from mint  
❌ **Don't skip validation** - verify all accounts  
❌ **Don't forget signer seeds** for PDA operations  

---

**Next:** [Cross-Program Invocation (CPI)](08-cpi.md) →
