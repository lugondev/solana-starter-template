---
layout: default
title: Home
nav_order: 1
description: "Solana Starter Program - A production-ready full-stack Solana development template"
permalink: /
---

# Solana Starter Program

A production-ready Solana development template featuring Anchor programs, TypeScript SDK, Next.js frontend, and high-performance Go indexer with complete cross-program invocation (CPI) patterns.
{: .fs-6 .fw-300 }

[Get Started]({% link setup-guide.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/your-username/solana-starter-program){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What's Included

| Component | Description |
|:----------|:------------|
| **Anchor Programs** | 2 programs with 24 instructions total |
| **Next.js Frontend** | Full-featured UI with Wallet Adapter |
| **Go Indexer** | High-performance blockchain indexer |
| **Test Suite** | 27 passing integration tests |
| **Documentation** | Comprehensive guides and references |

## Quick Links

- [Setup Guide]({% link setup-guide.md %}) - First time setup
- [Quick Reference]({% link quick-reference.md %}) - Commands cheat sheet  
- [Localnet Setup]({% link localnet-setup.md %}) - Local development
- [Integration Guide]({% link integration-guide.md %}) - Indexer + Programs
- [Docker Deployment]({% link docker-deployment.md %}) - Production deployment

## Features

### Starter Program (18 Instructions)

- Program configuration with pause mechanism
- User account management via PDAs
- SPL token operations (mint, transfer, burn)
- Cross-program invocation patterns

### Counter Program (6 Instructions)

- Initialize, increment, decrement, add, reset
- Payment integration for paid operations

### Frontend

- Next.js 16 with App Router
- React 19 with TypeScript
- Wallet adapter integration
- Real-time balance updates

### Go Indexer

- Concurrent block processing
- Automatic retry with exponential backoff
- PostgreSQL integration
- Health monitoring endpoints

---

## Getting Help

- Check the [Quick Reference]({% link quick-reference.md %}) for common commands
- Read [Localnet Setup]({% link localnet-setup.md %}) for development tips
- See [Completion Summary]({% link completion-summary.md %}) for project status
