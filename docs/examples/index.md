---
layout: default
title: Solana by Example
nav_order: 9
has_children: true
description: "Learn Solana programming through practical examples from starter_program"
---

# Solana by Example

Learn Solana/Anchor programming through real, production-ready code examples from the starter_program codebase.

{: .fs-6 .fw-300 }

---

## Introduction

This guide demonstrates essential Solana development patterns using actual code from this project. Each section focuses on a specific concept with working examples you can reference and modify.

**All examples are extracted from the `starter_program/` codebase**, which includes:
- 46 program instructions across 2 programs
- 96+ integration tests
- Production patterns for PDAs, tokens, CPI, RBAC, and more

---

## Learning Path

We recommend reading these sections in order:

### Fundamentals

1. [**Project Structure**](01-project-structure.md) - Anchor project layout and organization
2. [**Account State Design**](02-account-state.md) - Defining on-chain data structures
3. [**PDA (Program Derived Address)**](03-pda.md) - Creating and using PDAs
4. [**Account Constraints**](04-constraints.md) - Validating accounts with Anchor

### Core Patterns

5. [**Error Handling**](05-error-handling.md) - Custom errors and validation
6. [**Events**](06-events.md) - Emitting and listening to program events
7. [**SPL Token Operations**](07-spl-tokens.md) - Mint, transfer, burn tokens

### Advanced Features

8. [**Cross-Program Invocation (CPI)**](08-cpi.md) - Calling other programs
9. [**Role-Based Access Control**](09-rbac.md) - Permission system
10. [**Treasury Management**](10-treasury.md) - SOL deposit/withdrawal patterns
11. [**NFT Implementation**](11-nft.md) - Collections, minting, marketplace

### Testing

12. [**Testing Patterns**](12-testing.md) - Integration tests with TypeScript

---

## How to Use This Guide

Each section includes:
- **Code examples** with inline comments
- **Links to source files** in the repository
- **TypeScript client examples** for calling programs
- **Common patterns** and best practices

### Code Links

When you see a source link like this:
> **Source:** [`state/config.rs`](../../starter_program/programs/starter_program/src/state/config.rs)

Click it to view the complete implementation in the actual codebase.

### Copy-Paste Ready

All code examples are production-ready and can be copied directly into your own projects (with appropriate modifications).

---

## Prerequisites

Before diving in, you should have:
- Basic Rust knowledge
- Solana CLI installed
- Anchor framework installed (v0.31.1)
- Understanding of blockchain fundamentals

See [Setup Guide](../setup-guide.md) for installation instructions.

---

## Quick Navigation

| Category | Topics |
|----------|--------|
| **Basics** | Project structure, Account state, PDAs, Constraints |
| **Core** | Errors, Events, SPL Tokens |
| **Advanced** | CPI, RBAC, Treasury, NFTs |
| **Testing** | Integration tests, Event testing, CPI testing |

---

## Resources

- [Anchor Documentation](https://book.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Solana Developer Docs](https://docs.solana.com/)
- [SPL Token Documentation](https://spl.solana.com/token)

---

**Ready to start?** Begin with [Project Structure](01-project-structure.md) →
