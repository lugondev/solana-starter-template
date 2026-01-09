# Solana Starter Program Documentation

This directory contains the documentation site built with Jekyll and the Just the Docs theme.

## Quick Start

### Local Development

```bash
cd docs
./serve.sh dev
```

Visit: http://localhost:4000/solana-starter-program/

### Production Build

```bash
cd docs
./serve.sh prod
```

**Note**: Production build may fail locally due to SSL certificate issues with `remote_theme`. This is expected and works fine on GitHub Actions.

## Structure

```
docs/
├── _config.yml           # Base configuration (local development)
├── _config_prod.yml      # Production overrides (GitHub Pages)
├── serve.sh              # Build/serve script
├── Gemfile               # Ruby dependencies
├── index.md              # Homepage
├── setup-guide.md
├── overview.md
├── quick-reference.md
├── integration-guide.md
├── localnet-setup.md
├── docker-deployment.md
├── completion-summary.md
└── examples/             # Code examples collection
    ├── 01-project-structure.md
    ├── 02-account-state.md
    ├── 03-pda.md
    ├── 04-constraints.md
    ├── 05-error-handling.md
    ├── 06-events.md
    ├── 07-spl-tokens.md
    ├── 08-cpi.md
    ├── 09-rbac.md
    ├── 10-treasury.md
    ├── 11-nft.md
    └── 12-testing.md
```

## Build Modes

### Dev Mode (Default)
- Uses local `just-the-docs` gem
- Fast builds, no network required
- Live reload enabled
- Command: `./serve.sh dev`

### Production Mode
- Uses `remote_theme` for GitHub Pages compatibility
- Requires network to download theme
- Mimics GitHub Pages build
- Command: `./serve.sh prod`

## Deployment

Documentation is automatically deployed to GitHub Pages via GitHub Actions when changes are pushed to the `main` branch.

**Live URL**: https://lugondev.github.io/solana-starter-program/

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment information.

## Adding Content

### New Page

Create a new markdown file in `docs/` directory:

```markdown
---
layout: default
title: My New Page
nav_order: 5
---

# My New Page

Content goes here...
```

### New Example

Create a new markdown file in `docs/examples/` directory:

```markdown
---
layout: default
title: My Example
parent: Examples
nav_order: 13
---

# My Example

Example content...
```

## Theme Customization

All theme settings are in `_config.yml`. Available options:

- `color_scheme`: dark (default) | light
- `search_enabled`: true | false
- `back_to_top`: true | false
- `enable_copy_code_button`: true | false

See [Just the Docs documentation](https://just-the-docs.com/) for more options.

## Resources

- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [Just the Docs Theme](https://just-the-docs.com/)
- [Markdown Guide](https://www.markdownguide.org/)
- [GitHub Pages Docs](https://docs.github.com/en/pages)
