---
layout: default
title: 12. Testing Patterns
parent: Solana by Example
nav_order: 12
---

# 12. Testing Patterns

Learn how to write comprehensive integration tests for your Solana programs.

**Test Sources:**
- [`tests/starter_program.ts`](../../starter_program/tests/starter_program.ts)
- [`tests/cross_program.ts`](../../starter_program/tests/cross_program.ts)
- [`tests/rbac.ts`](../../starter_program/tests/rbac.ts)
- [`tests/treasury.ts`](../../starter_program/tests/treasury.ts)
- [`tests/advanced_token.ts`](../../starter_program/tests/advanced_token.ts)
- [`tests/nft-simple.ts`](../../starter_program/tests/nft-simple.ts)

---

## Basic Test Setup

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { StarterProgram } from "../target/types/starter_program";
import { expect } from "chai";
import { 
  SystemProgram, 
  LAMPORTS_PER_SOL,
  Keypair,
  PublicKey 
} from "@solana/web3.js";

describe("starter_program", () => {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.StarterProgram as Program<StarterProgram>;
  const admin = Keypair.generate();
  const user = Keypair.generate();

  before(async () => {
    // Airdrop SOL to test wallets
    const airdropAdmin = await provider.connection.requestAirdrop(
      admin.publicKey,
      2 * LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(airdropAdmin);

    const airdropUser = await provider.connection.requestAirdrop(
      user.publicKey,
      2 * LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(airdropUser);
  });

  // Tests go here...
});
```

---

## Test PDA Creation

```typescript
describe("User Accounts", () => {
  it("Should create user account", async () => {
    const [userPda, bump] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_account"), admin.publicKey.toBuffer()],
      program.programId
    );

    await program.methods
      .createUserAccount()
      .accounts({
        userAccount: userPda,
        authority: admin.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([admin])
      .rpc();

    // Fetch and verify account
    const account = await program.account.userAccount.fetch(userPda);
    expect(account.authority.toString()).to.equal(admin.publicKey.toString());
    expect(account.points.toNumber()).to.equal(0);
    expect(account.bump).to.equal(bump);
    expect(account.createdAt.toNumber()).to.be.greaterThan(0);
  });

  it("Should update user points", async () => {
    const [userPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_account"), admin.publicKey.toBuffer()],
      program.programId
    );

    const newPoints = 100;

    await program.methods
      .updateUserAccount(new anchor.BN(newPoints))
      .accounts({
        userAccount: userPda,
        authority: admin.publicKey,
      })
      .signers([admin])
      .rpc();

    const account = await program.account.userAccount.fetch(userPda);
    expect(account.points.toNumber()).to.equal(newPoints);
  });

  it("Should close user account", async () => {
    const [userPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_account"), user.publicKey.toBuffer()],
      program.programId
    );

    // Create account first
    await program.methods
      .createUserAccount()
      .accounts({
        userAccount: userPda,
        authority: user.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([user])
      .rpc();

    // Close account
    await program.methods
      .closeUserAccount()
      .accounts({
        userAccount: userPda,
        authority: user.publicKey,
      })
      .signers([user])
      .rpc();

    // Verify account is closed
    const account = await provider.connection.getAccountInfo(userPda);
    expect(account).to.be.null;
  });
});
```

---

## Test Error Cases

```typescript
describe("Error Handling", () => {
  it("Should fail with unauthorized access", async () => {
    const [configPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("program_config")],
      program.programId
    );

    const unauthorized = Keypair.generate();
    
    // Airdrop to unauthorized
    const airdrop = await provider.connection.requestAirdrop(
      unauthorized.publicKey,
      LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(airdrop);

    try {
      await program.methods
        .updateConfig(admin.publicKey, new anchor.BN(100))
        .accounts({
          programConfig: configPda,
          admin: unauthorized.publicKey,
        })
        .signers([unauthorized])
        .rpc();

      expect.fail("Should have thrown Unauthorized error");
    } catch (error) {
      expect(error.error.errorCode.code).to.equal("Unauthorized");
      expect(error.error.errorMessage).to.include("Unauthorized access");
    }
  });

  it("Should fail with invalid amount", async () => {
    const [treasuryPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("treasury")],
      program.programId
    );

    try {
      await program.methods
        .depositToTreasury(new anchor.BN(0))  // Invalid: zero amount
        .accounts({
          treasury: treasuryPda,
          depositor: user.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([user])
        .rpc();

      expect.fail("Should have thrown InvalidAmount error");
    } catch (error) {
      expect(error.error.errorCode.code).to.equal("InvalidAmount");
    }
  });
});
```

---

## Test Token Operations

```typescript
import { 
  getAssociatedTokenAddress, 
  getAccount,
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID 
} from "@solana/spl-token";

describe("Token Operations", () => {
  let mintPda: PublicKey;
  let mintAuthority: PublicKey;
  let userTokenAccount: PublicKey;

  before(async () => {
    [mintPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("mint")],
      program.programId
    );

    [mintAuthority] = PublicKey.findProgramAddressSync(
      [Buffer.from("mint_authority")],
      program.programId
    );

    userTokenAccount = await getAssociatedTokenAddress(
      mintPda,
      user.publicKey
    );

    // Create mint
    await program.methods
      .createMint()
      .accounts({
        signer: admin.publicKey,
        mint: mintPda,
        mintAuthority: mintAuthority,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
      })
      .signers([admin])
      .rpc();
  });

  it("Should mint tokens", async () => {
    const amount = 1_000_000; // 1 token with 6 decimals

    await program.methods
      .mintTokens(new anchor.BN(amount))
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

    // Verify balance
    const tokenAccount = await getAccount(
      provider.connection,
      userTokenAccount
    );
    expect(Number(tokenAccount.amount)).to.equal(amount);
  });

  it("Should transfer tokens", async () => {
    const recipient = Keypair.generate();
    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintPda,
      recipient.publicKey
    );

    const transferAmount = 100_000;

    await program.methods
      .transferTokens(new anchor.BN(transferAmount))
      .accounts({
        fromAccount: userTokenAccount,
        toAccount: recipientTokenAccount,
        mint: mintPda,
        authority: user.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([user])
      .rpc();

    // Verify balances
    const fromAccount = await getAccount(provider.connection, userTokenAccount);
    const toAccount = await getAccount(provider.connection, recipientTokenAccount);
    
    expect(Number(toAccount.amount)).to.equal(transferAmount);
  });

  it("Should burn tokens", async () => {
    const burnAmount = 50_000;

    const beforeBurn = await getAccount(provider.connection, userTokenAccount);
    const beforeBalance = Number(beforeBurn.amount);

    await program.methods
      .burnTokens(new anchor.BN(burnAmount))
      .accounts({
        tokenAccount: userTokenAccount,
        mint: mintPda,
        authority: user.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([user])
      .rpc();

    const afterBurn = await getAccount(provider.connection, userTokenAccount);
    expect(Number(afterBurn.amount)).to.equal(beforeBalance - burnAmount);
  });
});
```

---

## Test CPI

```typescript
describe("Cross-Program Invocation", () => {
  const counterProgram = anchor.workspace.CounterProgram as Program<any>;
  let counterPda: PublicKey;

  before(async () => {
    [counterPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("counter"), user.publicKey.toBuffer()],
      counterProgram.programId
    );

    // Initialize counter
    await counterProgram.methods
      .initialize()
      .accounts({
        counter: counterPda,
        authority: user.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([user])
      .rpc();
  });

  it("Should increment counter via CPI", async () => {
    const before = await counterProgram.account.counter.fetch(counterPda);
    const initialCount = before.count.toNumber();

    await program.methods
      .incrementCounter()
      .accounts({
        counter: counterPda,
        authority: user.publicKey,
        counterProgram: counterProgram.programId,
      })
      .signers([user])
      .rpc();

    const after = await counterProgram.account.counter.fetch(counterPda);
    expect(after.count.toNumber()).to.equal(initialCount + 1);
  });

  it("Should add to counter via CPI", async () => {
    const before = await counterProgram.account.counter.fetch(counterPda);
    const value = 10;

    await program.methods
      .addToCounter(new anchor.BN(value))
      .accounts({
        counter: counterPda,
        authority: user.publicKey,
        counterProgram: counterProgram.programId,
      })
      .signers([user])
      .rpc();

    const after = await counterProgram.account.counter.fetch(counterPda);
    expect(after.count.toNumber()).to.equal(before.count.toNumber() + value);
  });
});
```

---

## Test Events

```typescript
describe("Events", () => {
  it("Should emit TokensMintedEvent", async () => {
    let eventData: any = null;

    const listener = program.addEventListener(
      "TokensMintedEvent",
      (event, slot) => {
        eventData = event;
        console.log("Event received at slot", slot);
      }
    );

    const amount = 1000;

    await program.methods
      .mintTokens(new anchor.BN(amount))
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

    // Wait for event
    await new Promise((resolve) => setTimeout(resolve, 1000));

    expect(eventData).to.not.be.null;
    expect(eventData.amount.toNumber()).to.equal(amount);
    expect(eventData.mint.toString()).to.equal(mintPda.toString());
    expect(eventData.recipient.toString()).to.equal(userTokenAccount.toString());

    await program.removeEventListener(listener);
  });

  it("Should emit TreasuryDepositEvent", async () => {
    let depositEvent: any = null;

    const listener = program.addEventListener(
      "TreasuryDepositEvent",
      (event) => {
        depositEvent = event;
      }
    );

    const depositAmount = 1 * LAMPORTS_PER_SOL;

    await program.methods
      .depositToTreasury(new anchor.BN(depositAmount))
      .accounts({
        treasury: treasuryPda,
        depositor: user.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([user])
      .rpc();

    await new Promise((resolve) => setTimeout(resolve, 1000));

    expect(depositEvent).to.not.be.null;
    expect(depositEvent.amount.toNumber()).to.equal(depositAmount);
    expect(depositEvent.depositor.toString()).to.equal(user.publicKey.toString());

    await program.removeEventListener(listener);
  });
});
```

---

## Test Helpers

### Airdrop Helper

```typescript
async function airdrop(publicKey: PublicKey, amount: number = LAMPORTS_PER_SOL) {
  const signature = await provider.connection.requestAirdrop(publicKey, amount);
  await provider.connection.confirmTransaction(signature);
}
```

### Create User Helper

```typescript
async function createTestUser(): Promise<Keypair> {
  const user = Keypair.generate();
  await airdrop(user.publicKey, 2 * LAMPORTS_PER_SOL);
  return user;
}
```

### Fetch Account with Retry

```typescript
async function fetchAccountWithRetry<T>(
  program: Program,
  accountName: string,
  address: PublicKey,
  maxRetries: number = 3
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await program.account[accountName].fetch(address) as T;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  throw new Error("Failed to fetch account");
}
```

---

## Running Tests

### Run All Tests

```bash
anchor test
```

### Run Specific Test File

```bash
anchor test tests/starter_program.ts
```

### Run with Logs

```bash
anchor test -- --features debug
```

### Skip Build

```bash
anchor test --skip-build
```

---

## Best Practices

✅ **Use `before` hooks** - Set up test environment  
✅ **Test error cases** - Verify errors are thrown  
✅ **Clean up events** - Remove listeners after tests  
✅ **Use descriptive names** - Clear test descriptions  
✅ **Test edge cases** - Boundary conditions, zero values  
✅ **Verify state changes** - Fetch and assert account data  

❌ **Don't hardcode addresses** - Use PDAs  
❌ **Don't skip cleanup** - Memory leaks from listeners  
❌ **Don't test in isolation** - Test realistic flows  
❌ **Don't ignore async** - Always await transactions  

---

## Coverage Checklist

- [ ] All instructions tested
- [ ] Error cases covered
- [ ] CPI calls verified
- [ ] Events emitted correctly
- [ ] PDA derivation works
- [ ] Account constraints enforced
- [ ] Edge cases handled
- [ ] State transitions valid

---

**🎉 You've completed the Solana by Example guide!**

Return to [Overview](../overview.md) for more resources.
