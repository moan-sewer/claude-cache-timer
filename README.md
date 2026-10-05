# claude-cache-timer

A Claude Code status line that shows **how long your prompt cache has left** and **what to do about your context**, so you stop guessing whether stepping away will cost you.

<img width="1100" height="406" alt="screenshot of timer with helpful MANtroid sticker" src="https://github.com/user-attachments/assets/5bd1d419-7ab1-45c2-a091-6fefc63ad6a8" />


```
Cache 47:12 (1h)  |  ctx 6% cheap restart
Cache 3:20 (5m)   |  ctx 55% /compact at next break
Cache cold — next msg re-caches ~120k  |  ctx 92% wrap up or new session
```

## Why

Claude Code caches your conversation so each turn doesn't reprocess the whole history. If you're idle longer than the cache lifetime, your next message re-reads everything from scratch: slower, and it costs more.

I spent an evening building a homemade countdown (file timestamps, a keyboard macro that sent "Acknowledged. Standing by." to keep the cache alive) before learning that:

- **Claude Code already tells the status line the real expiry time**, for your session only, in the `prompt_cache` field.
- **The status line doesn't re-run while you're idle** unless you set `refreshInterval`, so homemade countdowns freeze exactly when you need them.
- **On a Pro/Max subscription, the main conversation gets a 1-hour cache by default**, not 5 minutes. API keys and paid usage credits get 5 minutes.
- **Keepalive pings aren't free.** Each one is a full turn that stays in your context forever.

This script reads the real data and shows it, so you can decide instead of guessing.

## What it shows

| Segment | Meaning |
| --- | --- |
| `Cache 47:12 (1h)` green | Cache is warm. Leave and come back any time before zero. |
| `Cache 0:45 (5m)` yellow | Last minute of a 5-minute cache, or last 5 minutes of a 1-hour cache. |
| `Cache cold — next msg re-caches ~120k` red | Cache expired. Your next message re-reads this many tokens once, then a fresh timer starts. |
| `ctx N% …` | How full the context window is, with a cue: *cheap restart* (<20%), *worth keeping* (<50%), */compact at next break* (<70%), */compact soon* (<85%), *wrap up or new session*. |

Every message you send resets the timer to the full TTL.

## Install

Requires **Claude Code v2.1.251 or later** and **jq**.

1. Install jq if you don't have it:
   ```bash
   brew install jq        # macOS
   sudo apt install jq    # Debian/Ubuntu
   ```

2. Download the script and make it executable:
   ```bash
   curl -o ~/.claude/cache-timer.sh https://raw.githubusercontent.com/moan-sewer/claude-cache-timer/main/cache-timer.sh
   chmod +x ~/.claude/cache-timer.sh
   ```

3. Add this to `~/.claude/settings.json` (or replace your existing `statusLine` block):
   ```json
   "statusLine": {
     "type": "command",
     "command": "bash ~/.claude/cache-timer.sh",
     "refreshInterval": 1
   }
   ```
   `refreshInterval: 1` is what makes the timer tick while you're idle.

4. Check the file is still valid JSON (a missing comma breaks *all* your settings, not just this):
   ```bash
   jq . ~/.claude/settings.json > /dev/null && echo "settings OK"
   ```

5. Restart Claude Code and send a message. The timer appears after the first response.

## Options

Open `cache-timer.sh` and edit the block at the top.

**Keep another status line.** If you already use one (from a plugin, say), set `PREPEND_CMD` and it shows in front of the timer, receiving the same session data:
```bash
PREPEND_CMD='bash "$HOME/.claude/my-other-statusline.sh"'
```

**Desktop notification (macOS).** Set `NOTIFY=1` to get one notification per cache window when the timer turns yellow.

**Context tiers.** Change the `CTX_TIER` numbers and labels to match how you like to work.

## Cache lifetime cheat sheet

| How you're billed | Main conversation cache |
| --- | --- |
| Pro/Max subscription, within plan usage | 1 hour |
| Paid usage credits, API key, cloud provider | 5 minutes |

- Want 1 hour everywhere? Add `"promptCacheTtl": "1h"` to settings.json. 1-hour cache writes are billed at a higher rate, so it's worth it if you idle a lot and not if you work in tight bursts.
- **Switching models** starts a cold cache: each model has its own.
- **`/compact` while the cache is warm is cheap.** Before a long break at high context, compacting means the cold restart re-reads a short summary instead of everything.

Details: [prompt caching](https://code.claude.com/docs/en/prompt-caching) and [status line](https://code.claude.com/docs/en/statusline) in the Claude Code docs.

## Test it without Claude Code

```bash
echo '{"prompt_cache":{"ttl":"1h","expires_at":'$(( $(date +%s) + 600 ))'},"context_window":{"used_percentage":35}}' | bash ~/.claude/cache-timer.sh
```

## License

MIT. Use it, change it, share it.
