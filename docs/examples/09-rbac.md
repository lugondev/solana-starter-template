---
layout: default
title: 9. Role-Based Access Control
parent: Solana by Example
nav_order: 9
---

# 9. Role-Based Access Control

Learn how to implement a flexible permission system using roles and bit flags.

**Source:** [`instructions/rbac.rs`](../../starter_program/programs/starter_program/src/instructions/rbac.rs)

---

## RBAC Overview

**Role-Based Access Control (RBAC)** allows you to:
- Assign roles to users (Admin, Moderator, User)
- Grant granular permissions (manage tokens, pause program, etc.)
- Update permissions dynamically
- Enforce access control in instructions

---

## Role State Structure

**Source:** [`state/role.rs`](../../starter_program/programs/starter_program/src/state/role.rs)

```rust
#[account]
pub struct Role {
    pub authority: Pubkey,       // Who has this role
    pub role_type: RoleType,     // Admin, Moderator, User
    pub permissions: u8,         // Bitmask for permissions
    pub assigned_by: Pubkey,     // Who assigned this role
    pub assigned_at: i64,        // When assigned
    pub updated_at: i64,         // Last update
    pub bump: u8,                // PDA bump
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

---

## Role Types and Default Permissions

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
            RoleType::Admin => 0xFF,     // All permissions (11111111)
            RoleType::Moderator => 0x06, // Limited permissions (00000110)
            RoleType::User => 0x00,      // No special permissions (00000000)
        }
    }
}
```

---

## Permission Flags

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

### Why Bitmasks?

✅ **Space efficient** - 8 permissions in 1 byte  
✅ **Fast operations** - Bitwise AND/OR  
✅ **Composable** - Combine permissions with `|`  
✅ **Easy to check** - Single bitwise operation  

---

## Assign Role

```rust
#[derive(Accounts)]
pub struct AssignRole<'info> {
    #[account(
        init,
        payer = admin,
        space = 8 + Role::LEN,
        seeds = [SEED_ROLE, target_authority.key().as_ref()],
        bump
    )]
    pub role: Account<'info, Role>,

    #[account(
        mut,
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        mut,
        constraint = admin.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub admin: Signer<'info>,

    /// CHECK: The user receiving the role
    pub target_authority: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}

pub fn assign_role_handler(ctx: Context<AssignRole>, role_type: RoleType) -> Result<()> {
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

## Update Permissions

```rust
#[derive(Accounts)]
pub struct UpdateRole<'info> {
    #[account(
        mut,
        seeds = [SEED_ROLE, role.authority.as_ref()],
        bump = role.bump
    )]
    pub role: Account<'info, Role>,

    #[account(
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        constraint = admin.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub admin: Signer<'info>,
}

pub fn update_role_permissions_handler(
    ctx: Context<UpdateRole>,
    add_permissions: u8,
    remove_permissions: u8,
) -> Result<()> {
    let role = &mut ctx.accounts.role;
    let clock = Clock::get()?;

    if add_permissions > 0 {
        role.add_permission(add_permissions);
    }

    if remove_permissions > 0 {
        role.remove_permission(remove_permissions);
    }

    role.updated_at = clock.unix_timestamp;

    msg!("Updated permissions for {}", role.authority);
    Ok(())
}
```

---

## Revoke Role

```rust
#[derive(Accounts)]
pub struct RevokeRole<'info> {
    #[account(
        mut,
        close = admin,  // Close and reclaim rent
        seeds = [SEED_ROLE, role.authority.as_ref()],
        bump = role.bump
    )]
    pub role: Account<'info, Role>,

    #[account(
        seeds = [SEED_PROGRAM_CONFIG],
        bump = program_config.bump,
    )]
    pub program_config: Account<'info, ProgramConfig>,

    #[account(
        mut,
        constraint = admin.key() == program_config.admin @ ErrorCode::Unauthorized
    )]
    pub admin: Signer<'info>,
}

pub fn revoke_role_handler(ctx: Context<RevokeRole>) -> Result<()> {
    msg!("Revoked role for {}", ctx.accounts.role.authority);
    Ok(())
}
```

---

## Check Permission

```rust
#[derive(Accounts)]
pub struct CheckPermission<'info> {
    #[account(
        seeds = [SEED_ROLE, authority.key().as_ref()],
        bump = role.bump
    )]
    pub role: Account<'info, Role>,

    pub authority: Signer<'info>,
}

pub fn check_permission_handler(
    ctx: Context<CheckPermission>,
    required_permission: u8,
) -> Result<bool> {
    let role = &ctx.accounts.role;

    require!(
        role.authority == ctx.accounts.authority.key(),
        ErrorCode::Unauthorized
    );

    Ok(role.has_permission(required_permission))
}
```

---

## Enforce Permissions in Instructions

### Pattern 1: Constraint-based

```rust
#[derive(Accounts)]
pub struct ManageTokens<'info> {
    #[account(
        seeds = [SEED_ROLE, authority.key().as_ref()],
        bump = role.bump,
        constraint = role.has_permission(permissions::MANAGE_TOKENS) 
            @ ErrorCode::InsufficientPermissions
    )]
    pub role: Account<'info, Role>,

    pub authority: Signer<'info>,

    // ... other accounts
}
```

### Pattern 2: In Handler

```rust
pub fn pause_program_handler(ctx: Context<PauseProgram>) -> Result<()> {
    // Check permission
    require!(
        ctx.accounts.role.has_permission(permissions::PAUSE_PROGRAM),
        ErrorCode::InsufficientPermissions
    );

    // Proceed with pause logic
    ctx.accounts.config.paused = true;
    
    Ok(())
}
```

---

## Client-Side Usage (TypeScript)

### Assign Admin Role

```typescript
const [rolePda] = PublicKey.findProgramAddressSync(
  [Buffer.from("role"), user.publicKey.toBuffer()],
  program.programId
);

await program.methods
  .assignRole({ admin: {} })  // RoleType::Admin
  .accounts({
    role: rolePda,
    programConfig: configPda,
    admin: admin.publicKey,
    targetAuthority: user.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([admin])
  .rpc();
```

### Update Permissions

```typescript
// Permission flags
const MANAGE_TOKENS = 1 << 2;   // 0b00000100
const MANAGE_USERS = 1 << 1;    // 0b00000010
const PAUSE_PROGRAM = 1 << 3;   // 0b00001000

// Add multiple permissions
const addPerms = MANAGE_TOKENS | MANAGE_USERS;  // 0b00000110

// Remove permission
const removePerms = PAUSE_PROGRAM;

await program.methods
  .updateRolePermissions(addPerms, removePerms)
  .accounts({
    role: rolePda,
    programConfig: configPda,
    admin: admin.publicKey,
  })
  .signers([admin])
  .rpc();
```

### Check Permission

```typescript
const [rolePda] = PublicKey.findProgramAddressSync(
  [Buffer.from("role"), user.publicKey.toBuffer()],
  program.programId
);

const MANAGE_TREASURY = 1 << 5;

const hasPermission = await program.methods
  .checkPermission(MANAGE_TREASURY)
  .accounts({
    role: rolePda,
    authority: user.publicKey,
  })
  .view();

console.log("Can manage treasury:", hasPermission);
```

---

## Permission Combinations

```typescript
// Check single permission
const canManageTokens = (role.permissions & MANAGE_TOKENS) !== 0;

// Check multiple permissions (has ANY)
const canManageUsersOrTokens = 
  (role.permissions & (MANAGE_USERS | MANAGE_TOKENS)) !== 0;

// Check multiple permissions (has ALL)
const requiredPerms = MANAGE_USERS | MANAGE_TOKENS;
const hasAllPerms = (role.permissions & requiredPerms) === requiredPerms;

// Grant multiple permissions
role.permissions |= (MANAGE_USERS | MANAGE_TOKENS);

// Revoke multiple permissions
role.permissions &= ~(MANAGE_USERS | MANAGE_TOKENS);
```

---

## Advanced: Hierarchical Roles

```rust
impl RoleType {
    pub fn can_assign(&self, target: RoleType) -> bool {
        match self {
            RoleType::Admin => true,  // Admin can assign any role
            RoleType::Moderator => {
                matches!(target, RoleType::User)  // Moderator can only assign User
            }
            RoleType::User => false,  // Users can't assign roles
        }
    }
}

pub fn assign_role_with_hierarchy_handler(
    ctx: Context<AssignRole>,
    role_type: RoleType
) -> Result<()> {
    let assigner_role = &ctx.accounts.assigner_role;
    
    require!(
        assigner_role.role_type.can_assign(role_type),
        ErrorCode::InsufficientPermissions
    );

    // ... assign role
    Ok(())
}
```

---

## Testing RBAC

```typescript
describe("RBAC Tests", () => {
  it("Admin should assign moderator role", async () => {
    await program.methods
      .assignRole({ moderator: {} })
      .accounts({
        role: moderatorRolePda,
        programConfig: configPda,
        admin: admin.publicKey,
        targetAuthority: moderator.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([admin])
      .rpc();

    const role = await program.account.role.fetch(moderatorRolePda);
    expect(role.roleType).to.deep.equal({ moderator: {} });
  });

  it("Should fail without permission", async () => {
    try {
      await program.methods
        .pauseProgram()
        .accounts({
          role: userRolePda,
          authority: user.publicKey,
          config: configPda,
        })
        .signers([user])
        .rpc();

      expect.fail("Should have thrown InsufficientPermissions");
    } catch (error) {
      expect(error.error.errorCode.code).to.equal("InsufficientPermissions");
    }
  });
});
```

---

## Best Practices

✅ **Use bitmasks for permissions** - Efficient and composable  
✅ **Emit events on role changes** - Auditability  
✅ **Validate role hierarchy** - Prevent privilege escalation  
✅ **Store assignment metadata** - Track who assigned when  
✅ **Use constraints** - Check permissions early  

❌ **Don't skip permission checks** - Always validate  
❌ **Don't use strings for roles** - Use enums  
❌ **Don't hardcode admin** - Use role system  

---

**Next:** [Treasury Management]({% link examples/10-treasury.md %}) →
