# Jekyll Documentation Deployment

## Overview

This project uses a dual-configuration approach for Jekyll deployment:
- **Local development**: Uses local `just-the-docs` gem (fast, no network required)
- **GitHub Pages**: Uses `remote_theme` plugin (required for GitHub Pages)

## Configuration Files

### `_config.yml` (Base Configuration)
Contains all site settings and uses `theme: just-the-docs` for local development.

### `_config_prod.yml` (Production Override)
Overrides the local theme with `remote_theme: just-the-docs/just-the-docs@v0.7.0` for GitHub Pages deployment.

## Local Development

```bash
cd docs

# Development mode (with live reload)
./serve.sh dev

# Production build test (attempts remote_theme, may fail locally due to SSL)
./serve.sh prod
```

## Deployment to GitHub Pages

Deployment is automatic via GitHub Actions when changes are pushed to the `main` branch.

The workflow:
1. Checks out code
2. Installs Ruby 3.3 and dependencies
3. Builds with: `jekyll build --config _config.yml,_config_prod.yml`
4. Deploys to GitHub Pages

**Key Build Command:**
```bash
bundle exec jekyll build --config _config.yml,_config_prod.yml --baseurl "/solana-starter-program"
```

This command merges both configs (left to right), where `_config_prod.yml` overrides values from `_config.yml`.

## How Config Override Works

Jekyll's `--config` flag accepts multiple files separated by commas:
```
--config file1.yml,file2.yml,file3.yml
```

Values are merged left-to-right, with later files overriding earlier ones:

**_config.yml:**
```yaml
theme: just-the-docs
plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
```

**_config_prod.yml:**
```yaml
remote_theme: just-the-docs/just-the-docs@v0.7.0
theme: null
plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-remote-theme
  - jekyll-github-metadata
```

**Result (merged):**
```yaml
remote_theme: just-the-docs/just-the-docs@v0.7.0
theme: null
plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-remote-theme
  - jekyll-github-metadata
```

## Why This Approach?

1. **Local Speed**: Dev mode uses local gem, no network downloads
2. **GitHub Compatibility**: GitHub Pages requires `remote_theme` plugin
3. **Single Source of Truth**: Main config stays in `_config.yml`
4. **Clean Overrides**: Production changes isolated in `_config_prod.yml`

## Troubleshooting

### Local Production Build Fails (SSL Error)
This is expected. The `remote_theme` plugin tries to download the theme from GitHub, which may fail locally due to SSL certificate verification. This works fine in GitHub Actions.

### Theme Not Loading on GitHub Pages
1. Verify `jekyll-remote-theme` plugin is in `Gemfile`
2. Check `_config_prod.yml` has correct `remote_theme` value
3. Ensure GitHub Actions workflow uses `--config _config.yml,_config_prod.yml`
4. Verify repository settings: Settings > Pages > Build and deployment > Source = "GitHub Actions"

### Changes Not Appearing
1. Wait 1-2 minutes for GitHub Actions to complete
2. Check Actions tab for build errors
3. Clear browser cache (Cmd+Shift+R)

## Repository Settings

Ensure GitHub Pages is configured correctly:

1. Go to: **Settings** > **Pages**
2. **Source**: Select "GitHub Actions" (not "Deploy from a branch")
3. Workflow will automatically deploy on push to `main`

## Manual Deployment

If you need to manually trigger deployment:

1. Go to: **Actions** tab
2. Select "Deploy Jekyll site to Pages" workflow
3. Click "Run workflow" > "Run workflow"

## Resources

- [Jekyll Configuration](https://jekyllrb.com/docs/configuration/)
- [Just the Docs Theme](https://just-the-docs.com/)
- [GitHub Pages with Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll)
- [jekyll-remote-theme Plugin](https://github.com/benbalter/jekyll-remote-theme)
