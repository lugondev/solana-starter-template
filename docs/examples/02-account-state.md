---
layout: default
title: 2. Account State Design
parent: Solana by Example
nav_order: 2
---

# 2. Account State Design

Learn how to define on-chain data structures with Anchor's `#[account]` macro.

---

## Basic Account Structure

**Source:** [`state/config.rs`](../../starter_program/programs/starter_program/src/state/config.rs)

```rust
use anchor_lang::prelude::*;

#[account]
pub struct ProgramConfig {
    pub admin: Pubkey,           // 32 bytes
    pub fee_destination: Pubkey, // 32 bytes
    pub fee_basis_points: u64,   // 8 bytes
    pub paused: bool,            // 1 byte
    pub bump: u8,                // 1 byte
}

impl ProgramConfig {
    // 8 (discriminator) + 32 + 32 + 8 + 1 + 1 = 82 bytes
    pub const LEN: usize = 8 + 32 + 32 + 8 + 1 + 1;
}
```

### Key Points

- `#[account]` macro generates serialization/deserialization code
- **Discriminator**: First 8 bytes identify the account type
- **Size calculation**: Always include the 8-byte discriminator
- **Bump storage**: Store PDA bump for efficient validation

---

## Account with Timestamps

**Source:** [`state/user.rs`](../../starter_program/programs/starter_program/src/state/user.rs)

```rust
#[account]
pub struct UserAccount {
    pub authority: Pubkey,  // Owner of this account
    pub points: u64,        // User's points balance
    pub created_at: i64,    // Unix timestamp
    pub updated_at: i64,    // Last update timestamp
    pub bump: u8,           // PDA bump seed
}

impl UserAccount {
    pub const LEN: usize = 8 + 32 + 8 + 8 + 8 + 1;
}
```

### Getting Current Timestamp

```rust
use anchor_lang::prelude::*;

pub fn create_user_account_handler(ctx: Context<CreateUserAccount>) -> Result<()> {
    let user = &mut ctx.accounts.user_account;
    let clock = Clock::get()?;
    
    user.authority = ctx.accounts.authority.key();
    user.points = 0;
    user.created_at = clock.unix_timestamp;
    user.updated_at = clock.unix_timestamp;
    user.bump = ctx.bumps.user_account;
    
    Ok(())
}
```

---

## Account with Methods

**Source:** [`state/role.rs`](../../starter_program/programs/starter_program/src/state/role.rs)

```rust
#[account]
pub struct Role {
    pub authority: Pubkey,
    pub role_type: RoleType,
    pub permissions: u8,      // Bitmask for permissions
    pub assigned_by: Pubkey,
    pub assigned_at: i64,
    pub updated_at: i64,
    pub bump: u8,
}

impl Role {
    pub const LEN: usize = 8 + 32 + 1 + 1 + 32 + 8 + 8 + 1;

    // Check if role has a specific permission
    pub fn has_permission(&self, permission: u8) -> bool {
        (self.permissions & permission) != 0
    }

    // Add permission using bitwise OR
    pub fn add_permission(&mut self, permission: u8) {
        self.permissions |= permission;
    }

    // Remove permission using bitwise AND with NOT
    pub fn remove_permission(&mut self, permission: u8) {
        self.permissions &= !permission;
    }
}
```

### Usage Example

```rust
pub fn check_permission_handler(ctx: Context<CheckPermission>) -> Result<()> {
    let role = &ctx.accounts.role;
    
    require!(
        role.has_permission(permissions::MANAGE_TOKENS),
        ErrorCode::InsufficientPermissions
    );
    
    // Permission granted, proceed...
    Ok(())
}
```

---

## Enum State

```rust
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum RoleType {
    Admin,
    Moderator,
    User,
}

impl RoleType {
    pub fn default_permissions(&self) -> u8 {
        match self {
            RoleType::Admin => 0xFF,     // All permissions
            RoleType::Moderator => 0x06, // Limited permissions
            RoleType::User => 0x00,      // No special permissions
        }
    }
}
```

### Enum Size

Enums in Anchor are 1 byte + size of largest variant:

```rust
pub enum Status {
    Active,           // 1 byte (discriminant only)
    Paused,           // 1 byte
    Closed,           // 1 byte
}

pub enum ComplexStatus {
    Active,                    // 1 + 0 = 1 byte
    Locked { until: i64 },     // 1 + 8 = 9 bytes
    Banned { reason: String }, // 1 + 4 + len = variable
}
```

**Size = 1 byte + largest variant size**

---

## Bitmask Permissions

Efficient permission storage using bit flags:

```rust
pub mod permissions {
    pub const MANAGE_CONFIG: u8 = 1 << 0;      // 0b00000001
    pub const MANAGE_USERS: u8 = 1 << 1;       // 0b00000010
    pub const MANAGE_TOKENS: u8 = 1 << 2;      // 0b00000100
    pub const PAUSE_PROGRAM: u8 = 1 << 3;      // 0b00001000
    pub const EMERGENCY_ACTIONS: u8 = 1 << 4;  // 0b00010000
    pub const MANAGE_TREASURY: u8 = 1 << 5;    // 0b00100000
    pub const MANAGE_ROLES: u8 = 1 << 6;       // 0b01000000
    pub const BATCH_OPERATIONS: u8 = 1 << 7;   // 0b10000000
}
```

### Combining Permissions

```rust
// Check single permission
if role.has_permission(permissions::MANAGE_TOKENS) {
    // User can manage tokens
}

// Check multiple permissions (any)
let can_manage = role.has_permission(permissions::MANAGE_TOKENS)
    || role.has_permission(permissions::MANAGE_USERS);

// Assign multiple permissions at once
let admin_perms = permissions::MANAGE_CONFIG 
    | permissions::MANAGE_USERS 
    | permissions::MANAGE_TOKENS;

role.permissions = admin_perms;
```

**Benefits:**
- Store up to 8 permissions in 1 byte
- Fast bitwise operations
- Memory efficient
- Easy to extend (use u16/u32 for more permissions)

---

## Size Calculation Reference

| Type | Size (bytes) | Example |
|------|-------------|---------|
| `bool` | 1 | `is_active: bool` |
| `u8`, `i8` | 1 | `count: u8` |
| `u16`, `i16` | 2 | `id: u16` |
| `u32`, `i32` | 4 | `amount: u32` |
| `u64`, `i64` | 8 | `lamports: u64` |
| `u128`, `i128` | 16 | `large_number: u128` |
| `Pubkey` | 32 | `owner: Pubkey` |
| `String` | 4 + len | `name: String` (max len) |
| `Vec<T>` | 4 + (len * T::size) | `items: Vec<u64>` |
| `Option<T>` | 1 + T::size | `maybe: Option<u64>` |
| Enum | 1 + largest variant | `status: Status` |
| **Discriminator** | 8 | Always added by Anchor |

### Example Calculation

```rust
#[account]
pub struct MyAccount {
    pub owner: Pubkey,        // 32
    pub balance: u64,         // 8
    pub created_at: i64,      // 8
    pub is_active: bool,      // 1
    pub status: Status,       // 1 (enum)
    pub bump: u8,             // 1
}

impl MyAccount {
    // 8 (discriminator) + 32 + 8 + 8 + 1 + 1 + 1 = 59 bytes
    pub const LEN: usize = 8 + 32 + 8 + 8 + 1 + 1 + 1;
}
```

---

## Variable-Length Data

For dynamic data, calculate maximum size:

```rust
#[account]
pub struct NftMetadata {
    pub name: String,    // Max 32 chars
    pub symbol: String,  // Max 10 chars
    pub uri: String,     // Max 200 chars
    // ...
}

impl NftMetadata {
    pub const MAX_NAME_LENGTH: usize = 32;
    pub const MAX_SYMBOL_LENGTH: usize = 10;
    pub const MAX_URI_LENGTH: usize = 200;
    
    pub const LEN: usize = 8 
        + 4 + Self::MAX_NAME_LENGTH 
        + 4 + Self::MAX_SYMBOL_LENGTH 
        + 4 + Self::MAX_URI_LENGTH;
}
```

**Validation:**

```rust
require!(
    name.len() <= NftMetadata::MAX_NAME_LENGTH,
    ErrorCode::NameTooLong
);
```

---

## Best Practices

✅ **Always store bump seeds** - Avoids recomputation  
✅ **Add timestamps** - Track creation/update times  
✅ **Use bitmasks** - Efficient permission storage  
✅ **Calculate LEN correctly** - Include discriminator (8 bytes)  
✅ **Validate variable data** - Enforce maximum lengths  
✅ **Add helper methods** - Encapsulate business logic  
✅ **Document sizes** - Comment byte sizes inline  

---

**Next:** [PDA (Program Derived Address)]({% link examples/03-pda.md %}) →
