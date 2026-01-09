---
layout: default
title: 11. NFT Implementation
parent: Solana by Example
nav_order: 11
---

# 11. NFT Implementation

Learn how to build a simple NFT system with collections, minting, and marketplace features.

**Sources:**
- [`state/nft.rs`](../../starter_program/programs/starter_program/src/state/nft.rs)
- [`instructions/nft.rs`](../../starter_program/programs/starter_program/src/instructions/nft.rs)

---

## NFT State Structures

### Collection Account

```rust
#[account]
pub struct NftCollection {
    pub authority: Pubkey,
    pub collection_mint: Pubkey,
    pub name: String,
    pub symbol: String,
    pub uri: String,
    pub seller_fee_basis_points: u16,  // Royalty (e.g., 500 = 5%)
    pub total_supply: u64,             // 0 = unlimited
    pub minted_count: u64,
    pub is_mutable: bool,
    pub created_at: i64,
    pub bump: u8,
}

impl NftCollection {
    pub const MAX_NAME_LENGTH: usize = 32;
    pub const MAX_SYMBOL_LENGTH: usize = 10;
    pub const MAX_URI_LENGTH: usize = 200;
    
    pub const LEN: usize = 8  // discriminator
        + 32  // authority
        + 32  // collection_mint
        + 4 + Self::MAX_NAME_LENGTH
        + 4 + Self::MAX_SYMBOL_LENGTH
        + 4 + Self::MAX_URI_LENGTH
        + 2   // seller_fee_basis_points
        + 8   // total_supply
        + 8   // minted_count
        + 1   // is_mutable
        + 8   // created_at
        + 1;  // bump
}
```

### NFT Metadata

```rust
#[account]
pub struct NftMetadata {
    pub mint: Pubkey,
    pub collection: Pubkey,
    pub owner: Pubkey,
    pub name: String,
    pub symbol: String,
    pub uri: String,
    pub creators: Vec<Creator>,
    pub is_mutable: bool,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Creator {
    pub address: Pubkey,
    pub verified: bool,
    pub share: u8,  // Percentage (0-100)
}
```

### NFT Listing (Marketplace)

```rust
#[account]
pub struct NftListing {
    pub seller: Pubkey,
    pub nft_mint: Pubkey,
    pub nft_token_account: Pubkey,
    pub price: u64,
    pub currency_mint: Option<Pubkey>,  // None = SOL
    pub listed_at: i64,
    pub expires_at: Option<i64>,
    pub bump: u8,
}

impl NftListing {
    pub const LEN: usize = 8 + 32 + 32 + 32 + 8 + 1 + 32 + 8 + 1 + 8 + 1;
    
    pub fn is_expired(&self, current_timestamp: i64) -> bool {
        if let Some(expires_at) = self.expires_at {
            current_timestamp > expires_at
        } else {
            false
        }
    }
}
```

---

## Create Collection

```rust
#[derive(Accounts)]
pub struct CreateCollection<'info> {
    #[account(
        init,
        payer = authority,
        space = NftCollection::LEN,
        seeds = [SEED_NFT_COLLECTION, collection_mint.key().as_ref()],
        bump
    )]
    pub collection: Account<'info, NftCollection>,

    pub collection_mint: Account<'info, Mint>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn create_collection_handler(
    ctx: Context<CreateCollection>,
    name: String,
    symbol: String,
    uri: String,
    seller_fee_basis_points: u16,
    total_supply: u64,
    is_mutable: bool,
) -> Result<()> {
    // Validate inputs
    require!(
        name.len() <= NftCollection::MAX_NAME_LENGTH,
        ErrorCode::NameTooLong
    );
    require!(
        symbol.len() <= NftCollection::MAX_SYMBOL_LENGTH,
        ErrorCode::SymbolTooLong
    );
    require!(
        uri.len() <= NftCollection::MAX_URI_LENGTH,
        ErrorCode::UriTooLong
    );
    require!(
        seller_fee_basis_points <= 10000,
        ErrorCode::InvalidRoyalty
    );

    let collection = &mut ctx.accounts.collection;
    let clock = Clock::get()?;

    collection.authority = ctx.accounts.authority.key();
    collection.collection_mint = ctx.accounts.collection_mint.key();
    collection.name = name;
    collection.symbol = symbol;
    collection.uri = uri;
    collection.seller_fee_basis_points = seller_fee_basis_points;
    collection.total_supply = total_supply;
    collection.minted_count = 0;
    collection.is_mutable = is_mutable;
    collection.created_at = clock.unix_timestamp;
    collection.bump = ctx.bumps.collection;

    msg!("Collection created: {}", collection.name);
    Ok(())
}
```

---

## Mint NFT

```rust
#[derive(Accounts)]
pub struct MintNft<'info> {
    #[account(
        mut,
        seeds = [SEED_NFT_COLLECTION, collection.collection_mint.as_ref()],
        bump = collection.bump,
        constraint = collection.authority == authority.key() @ ErrorCode::Unauthorized
    )]
    pub collection: Account<'info, NftCollection>,

    #[account(
        init,
        payer = authority,
        space = NftMetadata::LEN,
        seeds = [SEED_NFT_METADATA, nft_mint.key().as_ref()],
        bump
    )]
    pub nft_metadata: Account<'info, NftMetadata>,

    #[account(
        init,
        payer = authority,
        mint::decimals = 0,  // NFT has 0 decimals
        mint::authority = authority,
        mint::token_program = token_program,
    )]
    pub nft_mint: Account<'info, Mint>,

    #[account(
        init_if_needed,
        payer = authority,
        associated_token::mint = nft_mint,
        associated_token::authority = recipient,
        associated_token::token_program = token_program,
    )]
    pub recipient_token_account: Account<'info, TokenAccount>,

    /// CHECK: NFT recipient
    pub recipient: AccountInfo<'info>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn mint_nft_handler(
    ctx: Context<MintNft>,
    name: String,
    uri: String,
    creators: Vec<Creator>,
) -> Result<()> {
    let collection = &mut ctx.accounts.collection;

    // Check supply limit
    require!(
        collection.total_supply == 0 || collection.minted_count < collection.total_supply,
        ErrorCode::SupplyExceeded
    );

    // Validate creators share totals 100%
    let total_share: u16 = creators.iter().map(|c| c.share as u16).sum();
    require!(total_share == 100, ErrorCode::InvalidCreatorShares);

    // Setup metadata
    let nft_metadata = &mut ctx.accounts.nft_metadata;
    nft_metadata.mint = ctx.accounts.nft_mint.key();
    nft_metadata.collection = collection.key();
    nft_metadata.owner = ctx.accounts.recipient.key();
    nft_metadata.name = name;
    nft_metadata.symbol = collection.symbol.clone();
    nft_metadata.uri = uri;
    nft_metadata.creators = creators;
    nft_metadata.is_mutable = collection.is_mutable;
    nft_metadata.bump = ctx.bumps.nft_metadata;

    // Increment minted count
    collection.minted_count = collection
        .minted_count
        .checked_add(1)
        .ok_or(ErrorCode::ArithmeticOverflow)?;

    // Mint 1 token to recipient (NFT = 1 token with 0 decimals)
    token::mint_to(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            MintTo {
                mint: ctx.accounts.nft_mint.to_account_info(),
                to: ctx.accounts.recipient_token_account.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
            },
        ),
        1,  // NFT = exactly 1 token
    )?;

    msg!("NFT minted: {} to {}", nft_metadata.name, nft_metadata.owner);
    Ok(())
}
```

---

## List NFT for Sale

```rust
#[derive(Accounts)]
pub struct ListNft<'info> {
    #[account(
        init,
        payer = seller,
        space = NftListing::LEN,
        seeds = [
            SEED_NFT_LISTING,
            nft_mint.key().as_ref(),
            seller.key().as_ref()
        ],
        bump
    )]
    pub listing: Account<'info, NftListing>,

    pub nft_mint: Account<'info, Mint>,

    #[account(
        constraint = nft_token_account.owner == seller.key() @ ErrorCode::NotNftOwner,
        constraint = nft_token_account.mint == nft_mint.key() @ ErrorCode::InvalidMint,
        constraint = nft_token_account.amount == 1 @ ErrorCode::InvalidAmount
    )]
    pub nft_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub seller: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn list_nft_handler(
    ctx: Context<ListNft>,
    price: u64,
    currency_mint: Option<Pubkey>,
    expires_at: Option<i64>,
) -> Result<()> {
    require!(price > 0, ErrorCode::InvalidAmount);

    let listing = &mut ctx.accounts.listing;
    let clock = Clock::get()?;

    listing.seller = ctx.accounts.seller.key();
    listing.nft_mint = ctx.accounts.nft_mint.key();
    listing.nft_token_account = ctx.accounts.nft_token_account.key();
    listing.price = price;
    listing.currency_mint = currency_mint;
    listing.listed_at = clock.unix_timestamp;
    listing.expires_at = expires_at;
    listing.bump = ctx.bumps.listing;

    msg!("NFT listed for {} lamports", price);
    Ok(())
}
```

---

## Buy NFT

```rust
#[derive(Accounts)]
pub struct BuyNft<'info> {
    #[account(
        mut,
        close = seller,  // Close listing after sale
        seeds = [
            SEED_NFT_LISTING,
            listing.nft_mint.as_ref(),
            listing.seller.as_ref()
        ],
        bump = listing.bump
    )]
    pub listing: Account<'info, NftListing>,

    #[account(
        mut,
        seeds = [SEED_NFT_METADATA, nft_mint.key().as_ref()],
        bump = nft_metadata.bump
    )]
    pub nft_metadata: Account<'info, NftMetadata>,

    pub nft_mint: Account<'info, Mint>,

    #[account(mut)]
    pub seller_nft_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        associated_token::mint = nft_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_nft_account: Account<'info, TokenAccount>,

    #[account(mut)]
    /// CHECK: Seller receives payment
    pub seller: AccountInfo<'info>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn buy_nft_handler(ctx: Context<BuyNft>) -> Result<()> {
    let listing = &ctx.accounts.listing;
    let clock = Clock::get()?;

    // Check not expired
    require!(
        !listing.is_expired(clock.unix_timestamp),
        ErrorCode::ListingExpired
    );

    // Only SOL payments in this example
    require!(listing.currency_mint.is_none(), ErrorCode::InvalidMint);

    // Transfer SOL from buyer to seller
    **ctx.accounts.buyer.try_borrow_mut_lamports()? -= listing.price;
    **ctx.accounts.seller.try_borrow_mut_lamports()? += listing.price;

    // Transfer NFT from seller to buyer
    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.seller_nft_account.to_account_info(),
                to: ctx.accounts.buyer_nft_account.to_account_info(),
                authority: ctx.accounts.seller.to_account_info(),
            },
        ),
        1,  // NFT = 1 token
    )?;

    // Update ownership in metadata
    let nft_metadata = &mut ctx.accounts.nft_metadata;
    nft_metadata.owner = ctx.accounts.buyer.key();

    msg!("NFT sold for {} lamports", listing.price);
    Ok(())
}
```

---

## Cancel Listing

```rust
#[derive(Accounts)]
pub struct CancelListing<'info> {
    #[account(
        mut,
        close = seller,
        seeds = [
            SEED_NFT_LISTING,
            listing.nft_mint.as_ref(),
            seller.key().as_ref()
        ],
        bump = listing.bump,
        constraint = listing.seller == seller.key() @ ErrorCode::Unauthorized
    )]
    pub listing: Account<'info, NftListing>,

    #[account(mut)]
    pub seller: Signer<'info>,
}

pub fn cancel_listing_handler(ctx: Context<CancelListing>) -> Result<()> {
    msg!("Listing cancelled");
    Ok(())
}
```

---

## Client-Side (TypeScript)

### Create Collection

```typescript
const collectionMint = Keypair.generate();

await program.methods
  .createCollection(
    "My NFT Collection",
    "MNFT",
    "https://arweave.net/collection-metadata",
    500,  // 5% royalty
    new BN(10000),  // Max supply
    true  // is_mutable
  )
  .accounts({
    collection: collectionPda,
    collectionMint: collectionMint.publicKey,
    authority: creator.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([creator, collectionMint])
  .rpc();
```

### Mint NFT

```typescript
const nftMint = Keypair.generate();

const creators = [
  {
    address: creator.publicKey,
    verified: true,
    share: 100,
  },
];

await program.methods
  .mintNft(
    "Cool NFT #1",
    "https://arweave.net/nft-metadata",
    creators
  )
  .accounts({
    collection: collectionPda,
    nftMetadata: nftMetadataPda,
    nftMint: nftMint.publicKey,
    recipientTokenAccount: recipientAta,
    recipient: recipient.publicKey,
    authority: creator.publicKey,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
  })
  .signers([creator, nftMint])
  .rpc();
```

### List NFT

```typescript
const price = 5 * LAMPORTS_PER_SOL; // 5 SOL
const expiresAt = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60; // 7 days

await program.methods
  .listNft(new BN(price), null, new BN(expiresAt))
  .accounts({
    listing: listingPda,
    nftMint: nftMint.publicKey,
    nftTokenAccount: sellerNftAta,
    seller: seller.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([seller])
  .rpc();
```

### Buy NFT

```typescript
await program.methods
  .buyNft()
  .accounts({
    listing: listingPda,
    nftMetadata: nftMetadataPda,
    nftMint: nftMint.publicKey,
    sellerNftAccount: sellerNftAta,
    buyerNftAccount: buyerNftAta,
    seller: seller.publicKey,
    buyer: buyer.publicKey,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
  })
  .signers([buyer])
  .rpc();
```

---

## Best Practices

✅ **NFT = 0 decimals** - Always use `mint::decimals = 0`  
✅ **Verify ownership** - Check token account owner before transfers  
✅ **Validate creators** - Ensure shares add up to 100%  
✅ **Check expiration** - Prevent buying expired listings  
✅ **Close listings** - Reclaim rent after sale/cancel  

❌ **Don't skip supply checks** - Prevent over-minting  
❌ **Don't forget royalties** - Track seller fees  
❌ **Don't allow 0 price** - Validate listing prices  

---

**Next:** [Testing Patterns]({% link examples/12-testing.md %}) →
