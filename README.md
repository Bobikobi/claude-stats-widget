# Claude Stats Widget

A small desktop widget for Linux that shows your Claude Code usage: how much of
your session and weekly quota is gone, how much you have written, and a
contribution-style heatmap of your activity — with Clawd, the Claude Code
mascot, wandering around at the bottom.

GTK3, a single self-contained file, no dependencies beyond what a normal
desktop already has.

```text
✳ Claude Code — Usage                        ⟳  🗕  עב  ✕

  Sessions      Messages     Total tokens   Active days
  5             3,233        2.4M           2

  Current streak Longest streak Peak hour    Favorite model
  2d             2d             11 PM        Opus 5

  Session quota used   50%   ████████░░░░░░░░
  Week quota used      46%   ███████░░░░░░░░░

  ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪
  ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪   ← 19 weeks of activity
  ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪

                 (Clawd walks here)
  You've used ~15× more tokens than Pride and Prejudice.
```

## Where the numbers come from

**Quota meters — real, from the server.** The widget runs
`claude -p "/usage" --output-format json` in the background every five minutes
and reads the answer. This costs nothing: `/usage` is answered locally by the
CLI, so the call reports `num_turns: 0` and `total_cost_usd: 0`. No window
opens, nothing is sent to a model.

100% means blocked. The tooltip shows when the quota resets and how old the
reading is.

If the `claude` CLI is not on `PATH`, or the call fails, the meters fall back to
showing how far the current usage window has run — clearly labelled as time
progress, not quota, so it never pretends to know something it does not.

**Everything else — from your local logs.** Sessions, messages, tokens,
streaks, peak hour, favourite model and the heatmap are computed from the
transcripts in `~/.claude/projects/**/*.jsonl`, using the same counting rules as
Claude's own stats page (every entry counted, no de-duplication).

Nothing is uploaded anywhere. The widget makes no network calls of its own.

## Install

```sh
git clone https://github.com/<you>/claude-stats-widget.git
cd claude-stats-widget
./install.sh
```

`install.sh` copies the script to `~/.local/bin`, generates the Clawd icon,
installs a desktop entry, and offers to start it at login. To remove
everything, run `./install.sh --uninstall`.

Manual install is just as easy — the widget is a single self-contained file:

```sh
cp claude-stats-widget ~/.local/bin/ && chmod +x ~/.local/bin/claude-stats-widget
```

## Usage

| Action | How |
|---|---|
| Switch to Hebrew and back | `עב` / `EN` button (see below) |
| Shrink to a corner cube | `🗕` button, `⤢` to expand again |
| Refresh now | `⟳` button |
| Move the window | Drag it (on Wayland: `Super` + drag) |
| Close | `✕` or `Esc` |
| Print stats as JSON | `claude-stats-widget --json` |

Preferences live in `~/.config/claude-stats-widget.json` and are remembered
between runs.

Desktop notifications fire at 80% and 95% of a quota, and again when it is
spent. They only ever fire on the real number from `/usage` — never on an
estimate.

## Hebrew, as a bonus

The interface is English by default. It also ships a complete Hebrew
translation: press `עב` and the whole widget switches, including a genuine
right-to-left layout — labels, tiles, alignment and notifications all flip. The
activity heatmap deliberately stays left-to-right in both languages, because it
is a timeline and reads chronologically either way.

Hebrew is selected automatically only if your desktop locale is already Hebrew
(`LANG=he_*`); otherwise English is the default. Your choice is remembered.

Adding another language is a matter of copying the `TR["en"]` block in the
source and translating the strings; nothing else is language-aware except the
text-direction switch.

## Clawd

Clawd is drawn as pixel art in the source, in Anthropic's coral (`#D97757`). He
picks his own activities: walking, running, jumping, jumping jacks, waving a
flag, stomping with confetti, looking around, blinking, napping with Zzz, and
sitting at a tiny laptop. When a Claude Code session is live on the machine he
notices and types along with you; when the weekly quota is nearly spent he
sulks. In the mini cube he sits in the corner and moves less.

## Requirements

- Linux desktop with GTK 3 (`python3-gi`, present by default on Ubuntu/Fedora)
- Python 3.9+
- Claude Code CLI on `PATH` for the real quota numbers (optional — the widget
  works without it, minus the quota meters)

Tested on Ubuntu with GNOME under Wayland. `set_keep_above` is honoured on X11
only; on Wayland use your compositor's "always on top" instead.

## Notes and limits

- The quota reading refreshes every five minutes, so during a heavy burst it
  can lag by a few percent. `/usage` in a session is always the live truth.
- `/usage` itself reports that its breakdown is approximate and covers only
  local sessions on this machine — not other devices or claude.ai.
- The widget reads its own logs only; it never reads message content for
  anything other than counting.

## License

MIT — see [LICENSE](LICENSE).

Clawd is Anthropic's mascot; the pixel rendition here is a fan tribute and this
project is not affiliated with or endorsed by Anthropic.
