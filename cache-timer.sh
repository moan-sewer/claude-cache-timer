#!/usr/bin/env bash
# claude-cache-timer
# A Claude Code status line that shows a live prompt-cache countdown
# and a context-window cue telling you when to keep going, compact, or restart.
#
# Requires: Claude Code v2.1.251+ and jq.
# Settings: add  "refreshInterval": 1  to your statusLine block so the timer ticks.
# License: MIT

# ---- Options: edit these --------------------------------------------------

# Show another status line in front of this one (for example a plugin's).
# It receives the same session JSON. Leave empty to show only the timer.
PREPEND_CMD=""
# Example: PREPEND_CMD='bash "$HOME/.claude/my-other-statusline.sh"'

# macOS only: show one desktop notification when the cache is about to go cold.
NOTIFY=0   # set to 1 to turn on

# Context cues: upper bound (%) for each tier, and its label.
CTX_TIER1=20; CTX_LABEL1="cheap restart"
CTX_TIER2=50; CTX_LABEL2="worth keeping"
CTX_TIER3=70; CTX_LABEL3="/compact at next break"
CTX_TIER4=85; CTX_LABEL4="/compact soon"
              CTX_LABEL5="wrap up or new session"

# ---------------------------------------------------------------------------

# Claude Code sends session JSON on stdin. Read it once and share it.
input=$(cat)

PREFIX=""
if [ -n "$PREPEND_CMD" ]; then
    OTHER=$(printf '%s' "$input" | eval "$PREPEND_CMD" 2>/dev/null)
    [ -n "$OTHER" ] && PREFIX="${OTHER}  |  "
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${PREFIX}\033[33mcache-timer needs jq (brew install jq)\033[0m"
    exit 0
fi

# Cache and context data for THIS session, straight from Claude Code.
IFS='|' read -r EXPIRES TTL RECACHE CTX SID <<< "$(printf '%s' "$input" | jq -r '
  [ (.prompt_cache.expires_at // ""),
    (.prompt_cache.ttl // ""),
    (.prompt_cache.recache_tokens_if_cold // ""),
    ((.context_window.used_percentage // "") | tostring | split(".")[0]),
    (.session_id // "session")
  ] | join("|")')"

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'
NOW=$(date +%s)

# 1. Cache countdown
if [ -z "$TTL" ]; then
    TIMER="${DIM}Cache: --${RESET}"          # no API response yet this session
else
    REMAINING=0
    [ -n "$EXPIRES" ] && REMAINING=$(( EXPIRES - NOW ))

    WARN=60                                  # last minute of a 5-minute cache
    [ "$TTL" = "1h" ] && WARN=300            # last 5 minutes of a 1-hour cache

    if [ "$REMAINING" -gt 0 ]; then
        CLOCK=$(printf '%d:%02d' $((REMAINING / 60)) $((REMAINING % 60)))
        if [ "$REMAINING" -gt "$WARN" ]; then COLOR=$GREEN; else COLOR=$YELLOW; fi
        TIMER="${COLOR}Cache ${CLOCK}${RESET} ${DIM}(${TTL})${RESET}"

        # One notification per cache window, when the timer turns yellow
        if [ "$NOTIFY" = "1" ] && [ "$REMAINING" -le "$WARN" ] && command -v osascript >/dev/null 2>&1; then
            FLAG="${TMPDIR:-/tmp}/claude-cache-timer-${SID}-${EXPIRES}"
            if [ ! -e "$FLAG" ]; then
                touch "$FLAG"
                osascript -e "display notification \"Cache goes cold in $(( (REMAINING + 59) / 60 )) min\" with title \"Claude Code\"" >/dev/null 2>&1 &
            fi
        fi
    else
        COST=""
        if [ -n "$RECACHE" ] && [ "$RECACHE" -gt 0 ] 2>/dev/null; then
            COST=" — next msg re-caches ~$(( (RECACHE + 500) / 1000 ))k"
        fi
        TIMER="${RED}Cache cold${COST}${RESET}"
    fi
fi

# 2. Context cue
CTXPART=""
if [ -n "$CTX" ] && [ "$CTX" != "null" ]; then
    if   [ "$CTX" -lt "$CTX_TIER1" ]; then C=$GREEN;  TIP=$CTX_LABEL1
    elif [ "$CTX" -lt "$CTX_TIER2" ]; then C=$GREEN;  TIP=$CTX_LABEL2
    elif [ "$CTX" -lt "$CTX_TIER3" ]; then C=$YELLOW; TIP=$CTX_LABEL3
    elif [ "$CTX" -lt "$CTX_TIER4" ]; then C=$YELLOW; TIP=$CTX_LABEL4
    else                                   C=$RED;    TIP=$CTX_LABEL5
    fi
    CTXPART="  |  ${C}ctx ${CTX}% ${TIP}${RESET}"
fi

echo -e "${PREFIX}${TIMER}${CTXPART}"
