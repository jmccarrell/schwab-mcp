set dotenv-load

@_:
    just --list


# ── Run ───────────────────────────────────────────────────────────────────────

# Start the MCP server (stdio transport — for use by Claude Code)
[group('run')]
serve:
    uv run schwab-mcp server --jesus-take-the-wheel --json

# Register this server with Claude Code (user scope — available in all projects)
[group('run')]
install-mcp:
    claude mcp add --scope user schwab-mcp -- uv run --project {{ justfile_directory() }} schwab-mcp server --jesus-take-the-wheel --json


# ── Auth ──────────────────────────────────────────────────────────────────────

# Run OAuth browser flow to create/refresh token
[group('auth')]
auth:
    uv run --env-file .env schwab-mcp auth

# Save client credentials to ~/.local/share/schwab-mcp/credentials.yaml
[group('auth')]
save-credentials:
    uv run --env-file .env schwab-mcp save-credentials --client-id "$SCHWAB_CLIENT_ID" --client-secret "$SCHWAB_CLIENT_SECRET"


# ── QA ────────────────────────────────────────────────────────────────────────

# Run tests
[group('qa')]
test *args:
    uv run -m pytest {{ args }}

# Run linters
[group('qa')]
lint:
    uvx ruff check
    uvx ruff format --check

# Check types
[group('qa')]
typing:
    uvx pyright


# ── Lifecycle ─────────────────────────────────────────────────────────────────

# Install Python deps (including technical analysis tools)
[group('lifecycle')]
install:
    uv sync --group ta

# Remove virtualenv and caches
[group('lifecycle')]
clean:
    rm -rf .venv .pytest_cache .ruff_cache
    find . -type d -name "__pycache__" -exec rm -r {} +
