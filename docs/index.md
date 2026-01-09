---
layout: default
title: Home
nav_order: 1
description: "Solana Starter Program - A production-ready full-stack Solana development template"
permalink: /
---

# Solana Starter Program

A comprehensive full-stack Solana development starter kit featuring Anchor programs, a modern Next.js frontend, and a Go-based event indexer. Demonstrates all essential Solana patterns including PDAs, SPL tokens, cross-program invocations, RBAC, NFTs, and real-time blockchain data indexing.
{: .fs-6 .fw-300 }

[Get Started]({% link setup-guide.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/your-username/solana-starter-program){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What's Included

| Component | Description |
|:----------|:------------|
| **Anchor Programs** | 2 programs with 23 instructions (Starter + Counter) |
| **Next.js Frontend** | Full-featured UI with 13 custom hooks and Wallet Adapter |
| **Go Indexer** | High-performance blockchain indexer (26+ event types) |
| **Test Suite** | 39+ passing integration tests |
| **Documentation** | Comprehensive guides and API references |

## Quick Links

- [Setup Guide]({% link setup-guide.md %}) - First time setup
- [Solana by Example]({% link examples/index.md %}) - Learn by code examples
- [Quick Reference]({% link quick-reference.md %}) - Commands cheat sheet  
- [Localnet Setup]({% link localnet-setup.md %}) - Local development
- [Integration Guide]({% link integration-guide.md %}) - Indexer + Programs
- [Docker Deployment]({% link docker-deployment.md %}) - Production deployment

## Features

### Starter Program (17 Instructions)

**Program Configuration:**
- Initialize and manage program config
- Pause/unpause mechanism
- Admin controls

**User Account Management:**
- PDA-based user accounts
- Points system
- Account lifecycle management

**SPL Token Operations:**
- Mint, transfer, and burn tokens
- Delegate approval and revocation
- Freeze/thaw token accounts

**Cross-Program Invocation:**
- Transfer SOL via CPI
- Transfer tokens with PDA signer
- Invoke Counter Program

**Role-Based Access Control:**
- Assign and revoke roles
- Update role permissions
- Permission checks

**Treasury Management:**
- Multi-sig treasury operations
- SOL deposits and withdrawals
- Distribution to multiple recipients

**NFT Support:**
- Collection creation
- NFT minting with metadata
- Marketplace (list/buy/cancel)
- Offer system

### Counter Program (6 Instructions)

- Initialize counter account
- Increment/decrement operations
- Add arbitrary value
- Reset (authority only)
- Increment with SOL payment

### Frontend Features

**UI Components:**
- 8 feature components for program interactions
- Wallet integration (Phantom, Solflare, Backpack, Torus)
- Real-time balance updates
- Loading states and error handling

**React Hooks (13 custom hooks):**
- `useBalance` - Real-time balance monitoring
- `useAccount` - Account information
- `useSendTransaction` - Transaction handling
- `useTransactionHistory` - Recent transactions
- `useStarterProgram` - User account operations
- `useTokenOperations` - Token management
- `useGovernance` - Proposal voting
- `useRoleManagement` - RBAC operations
- `useTreasury` - Treasury management
- `useNftCollection` - NFT creation
- `useNftMarketplace` - NFT trading
- `useCounterProgram` - Counter operations

**Technical Stack:**
- Next.js 16.1.1 with App Router
- React 19 with TypeScript 5.9
- Anchor 0.31.1 integration
- SWR for data fetching
- Tailwind CSS 4

### Go Indexer Features

**Core Capabilities:**
- Multi-program support (Starter + Counter)
- Dual decoding strategy (Anchor events + log parsing)
- Real-time event processing
- MongoDB and PostgreSQL support
- 26+ event types indexed

**Architecture:**
- Concurrent processing with configurable workers
- Automatic retry with exponential backoff
- Graceful shutdown handling
- Health monitoring endpoint
- Comprehensive error handling

**Performance:**
- Processes 50+ transactions/second
- <100ms latency
- Configurable batch size and concurrency

---

## Project Statistics

- **Programs:** 2 programs, 23 instructions total
- **Tests:** 39+ integration tests (100% passing)
- **Frontend:** 8 components, 13 custom hooks
- **Indexer:** 26+ event types, dual decoding
- **Code:** ~15,000+ lines total
- **Documentation:** ~5,000+ lines

## Getting Help

- Check the [Quick Reference]({% link quick-reference.md %}) for common commands
- Read [Localnet Setup]({% link localnet-setup.md %}) for development tips
- See [Completion Summary]({% link completion-summary.md %}) for project status
- Visit the [Examples]({% link examples/index.md %}) for code patterns
