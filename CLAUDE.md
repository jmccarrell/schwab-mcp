# schwab-mcp

MCP server that exposes the Schwab brokerage API as Claude tools. Provides market data, account info, option chains, order management, and technical analysis indicators.

Fork of [jkoelker/schwab-mcp](https://github.com/jkoelker/schwab-mcp) at [jmccarrell/schwab-mcp](https://github.com/jmccarrell/schwab-mcp).

## Tool Inventory

### Market Data (4 tools)
| Tool | Returns |
|------|---------|
| `get_datetime` | Current date/time |
| `get_market_hours` | Market open/close times |
| `get_movers` | Top gainers/losers for an index |
| `get_instruments` | Instrument search by symbol |

### Account (6 tools)
| Tool | Returns |
|------|---------|
| `get_account_numbers` | Linked account numbers |
| `get_accounts` | Account summaries |
| `get_accounts_with_positions` | Accounts + positions |
| `get_account` | Single account details |
| `get_account_with_positions` | Single account + positions |
| `get_user_preferences` | User preferences |

### Price History (8 tools)
| Tool | Returns |
|------|---------|
| `get_advanced_price_history` | Candles with full control over frequency/period |
| `get_price_history_every_minute` | 1-min candles |
| `get_price_history_every_five_minutes` | 5-min candles |
| `get_price_history_every_ten_minutes` | 10-min candles |
| `get_price_history_every_fifteen_minutes` | 15-min candles |
| `get_price_history_every_thirty_minutes` | 30-min candles |
| `get_price_history_every_day` | Daily candles |
| `get_price_history_every_week` | Weekly candles |

### Options (3 tools)
| Tool | Returns |
|------|---------|
| `get_option_chain` | Standard option chain |
| `get_advanced_option_chain` | Option chain with full filter control |
| `get_option_expiration_chain` | Available expiration dates |

### Quotes (1 tool)
| Tool | Returns |
|------|---------|
| `get_quotes` | Real-time quotes for symbols |

### Transactions (2 tools)
| Tool | Returns |
|------|---------|
| `get_transactions` | Trade/transfer history |
| `get_transaction` | Single transaction details |

### Orders — Read (6 tools)
| Tool | Returns |
|------|---------|
| `get_order` | Single order status |
| `get_orders` | All orders for account |
| `build_equity_order_spec` | Preview equity order JSON (no execution) |
| `build_equity_trailing_stop_order_spec` | Preview trailing stop JSON |
| `build_option_order_spec` | Preview option order JSON |
| `create_option_symbol` | Build OCC option symbol string |

### Orders — Write (8 tools, require approval)
| Tool | Action |
|------|--------|
| `cancel_order` | Cancel an open order |
| `place_equity_order` | Buy/sell stocks and ETFs |
| `place_option_order` | Buy/sell option contracts |
| `place_equity_trailing_stop_order` | Trailing stop order |
| `place_one_cancels_other_order` | OCO order pair |
| `place_first_triggers_second_order` | Conditional order chain |
| `place_bracket_order` | Entry + take profit + stop loss |
| `place_option_combo_order` | Multi-leg option strategy |

### Technical Analysis (12 tools)
| Tool | Indicator |
|------|-----------|
| `sma` | Simple Moving Average |
| `ema` | Exponential Moving Average |
| `rsi` | Relative Strength Index |
| `stoch` | Stochastic Oscillator |
| `macd` | MACD |
| `atr` | Average True Range |
| `adx` | Average Directional Index |
| `vwap` | Volume Weighted Average Price |
| `pivot_points` | Pivot Points |
| `bollinger_bands` | Bollinger Bands |
| `historical_volatility` | Historical Volatility |
| `expected_move` | Expected Move (from option chain IV) |

**Total: 50 tools** (30 read-only market/account + 6 order-read + 12 technical = 48 auto-allowed; 8 write = prompt for approval)

## Architecture

```
src/schwab_mcp/
    __init__.py       — entry point proxy
    cli.py            — Click CLI: auth, server, save-credentials subcommands
    server.py         — SchwabMCPServer wrapping FastMCP with lifespan
    context.py        — SchwabServerContext (client + approval_manager)
    auth.py           — OAuth flow via schwab-py
    tokens.py         — Token/credential storage (YAML, platformdirs)
    approvals/        — ApprovalManager (Discord or NoOp)
    tools/            — Tool registration by domain
        account.py, history.py, options.py, orders.py,
        quotes.py, tools.py, transactions.py
        technical/    — pandas-ta indicators (optional)
    resources.py      — MCP resources (read-only data)
```

- Built on `schwab-py` (custom fork with proxy support)
- CLI entry point: `schwab-mcp` → `schwab_mcp:main` → Click group
- Server uses `--jesus-take-the-wheel --json` flags — write tools exposed but gated by Claude Code permissions
- Technical tools require `pandas-ta-classic` (installed via `uv sync --group ta`)

## Auth Flow

1. **Save credentials**: `just save-credentials` reads `SCHWAB_CLIENT_ID` / `SCHWAB_CLIENT_SECRET` from `.env` and writes to `~/Library/Application Support/schwab-mcp/credentials.yaml`
2. **OAuth**: `just auth` opens browser for Schwab login, saves token to `~/Library/Application Support/schwab-mcp/token.yaml`
3. **Server startup**: reads credentials and token from `~/Library/Application Support/schwab-mcp/` — no env vars needed at runtime

Tokens expire after 7 days; re-run `just auth` to refresh.

## Setup

```bash
just install          # Sync deps (including pandas-ta)
just save-credentials # Save API credentials from .env to ~/.local/share/
just auth             # OAuth browser flow (after Schwab approves dev app)
just install-mcp      # Register with Claude Code (user scope, one-time)
just serve            # Start server manually (for debugging)
just test [args]      # Run pytest
just lint             # Ruff check + format check
just typing           # Type check (pyright)
just clean            # Remove .venv, caches
```

After `just install-mcp`, restart Claude Code to pick up the new server.

## Write Tool Safety

The server runs with `--jesus-take-the-wheel` so all 50 tools are exposed. Safety is enforced at the Claude Code permission layer:

- **42 read-only tools**: auto-allowed in `.claude/settings.local.json`
- **8 write tools**: NOT in the allow list — Claude Code prompts for explicit user approval on each trade

This is deliberate: it lets Claude build order specs and preview them, but requires human confirmation before any order placement or cancellation.

## Gotchas

- Server fails to start if no valid token exists — run `just auth` first
- Schwab dev app approval is required before auth can succeed
- Token max age is 7 days; re-authenticate weekly
- `--json` flag returns raw JSON; without it, responses use Toon-encoded strings
- Technical tools need `pandas-ta-classic` — install with `uv sync --group ta`
- The `save-credentials` command is non-interactive when passed `--client-id` / `--client-secret` flags
- MCP server name is `schwab-mcp` — tool names appear as `mcp__schwab-mcp__<tool_name>` in Claude Code
