#!/bin/bash
# Builds the release in _build/prod/rel/zero
set -euo pipefail

export MIX_ENV=prod

mix local.hex --force
mix local.rebar --force
mix release
