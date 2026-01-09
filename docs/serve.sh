#!/bin/bash
set -e

MODE="${1:-dev}"

if [ "$MODE" = "prod" ]; then
  echo "Building with production config (using remote_theme)..."
  bundle exec jekyll build --config _config.yml,_config_prod.yml
  echo "Production build complete. Files in _site/"
elif [ "$MODE" = "dev" ]; then
  echo "Starting development server (using local theme)..."
  bundle exec jekyll serve --livereload
else
  echo "Usage: ./serve.sh [dev|prod]"
  echo "  dev  - Local development with live reload (default)"
  echo "  prod - Production build with remote_theme"
  exit 1
fi
