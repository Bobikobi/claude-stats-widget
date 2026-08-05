# Claude Stats Widget

A small desktop widget that shows your Claude Code usage: how much of your
session and weekly quota is gone, how much you have written, and a
contribution-style heatmap of your activity - with Clawd, the Claude Code
mascot, wandering around at the bottom.

Runs on **Linux** (GTK3) and **Windows** (Tkinter). One self-contained file, no
dependencies beyond what the desktop already has.

```text
✳ Claude Code - Usage                        ⟳  🗕  עב  ✕

  Sessions      Messages     Total tokens   Active days
  5             3233         2.4M           2

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

**Quota meters - real, from the server.** The widget runs
`claude -p "/usage" --output-format json` in the background every five minutes
and reads the answer. This costs nothing: `/usage` is answered locally by the
CLI, so the call reports `num_turns: 0` and `total_cost_usd: 0`. No window
opens, nothing is sent to a model.

100% means blocked. The tooltip shows when the quota resets and how old the
reading is.

If the `claude` CLI is not on `PATH`, or the call fails, the meters fall back to
showing how far the current usage window has run - clearly labelled as time
progress, not quota, so it never pretends to know something it does not.

**Everything else - from your local logs.** Sessions, messages, tokens,
streaks, peak hour, favourite model and the heatmap are computed from the
transcripts in `~/.claude/projects/**/*.jsonl`, using the same counting rules as
Claude's own stats page (every entry counted, no de-duplication).

Nothing is uploaded anywhere. The widget makes no network calls of its own.

## Install

One line, no clone. Both installers write only inside your own user profile,
need no root or administrator rights, and put a shortcut on your desktop and in
your applications menu. Neither needs an editor, an IDE or any build tooling:
just Python, which is already there on most Linux desktops.

<details open>
<summary><b>Windows</b> (Tkinter)</summary>

```powershell
irm https://raw.githubusercontent.com/Bobikobi/claude-stats-widget/main/install.ps1 | iex
```

That fetches the widget, installs it to
`%LOCALAPPDATA%\Programs\claude-stats-widget`, draws the Clawd icon, adds
desktop and Start Menu shortcuts, and starts it.

To pass options through the one-liner, run it as a scriptblock:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Bobikobi/claude-stats-widget/main/install.ps1))) -Uninstall
```

`-Uninstall` removes everything and leaves your settings alone. The other
switches are `-NoAutostart`, `-NoDesktopShortcut` and `-NoLaunch`.

From a clone it is the same script:

```powershell
git clone https://github.com/Bobikobi/claude-stats-widget.git
cd claude-stats-widget
.\install.ps1
```

If PowerShell refuses to run it from disk, that is the execution policy, not
the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Manual install is a copy plus a shortcut to `pythonw.exe "<the file>"`. Use
`pythonw`, not `python`, or you get a console window next to the widget.

</details>

<details open>
<summary><b>Linux</b> (GTK3)</summary>

```sh
curl -fsSL https://raw.githubusercontent.com/Bobikobi/claude-stats-widget/main/install.sh | bash
```

That fetches the widget, installs it to `~/.local/bin`, draws the Clawd icon,
adds a desktop entry plus a desktop shortcut, and starts it. Piped like this
there is nobody to answer the autostart question, so it is not enabled; run the
script from a terminal if you want it.

```sh
git clone https://github.com/Bobikobi/claude-stats-widget.git
cd claude-stats-widget
./install.sh
```

`./install.sh --uninstall` removes everything and leaves your settings alone;
`--no-desktop-shortcut` skips the desktop copy.

Manual install is just as easy - the widget is a single self-contained file:

```sh
cp claude-stats-widget ~/.local/bin/ && chmod +x ~/.local/bin/claude-stats-widget
```

</details>

## Usage

| Action | How |
|---|---|
| Switch to Hebrew and back | `עב` / `EN` button (see below) |
| Shrink to a corner cube | `🗕` button, `⤢` to expand again |
| Refresh now | `⟳` button |
| Move the window | Drag it (on Wayland: `Super` + drag) |
| Close | `✕` or `Esc` |
| Print stats as JSON | `claude-stats-widget --json` |

Preferences are remembered between runs, in
`~/.config/claude-stats-widget.json` on Linux and
`%APPDATA%\claude-stats-widget\config.json` on Windows. On Windows the window
position is remembered too, since a frameless window gets no help from the
shell in staying where you put it.

Desktop notifications fire at 80% and 95% of a quota, and again when it is
spent: `notify-send` on Linux, a native toast on Windows. They only ever fire
on the real number from `/usage`, never on an estimate.

## Hebrew, as a bonus

The interface is English by default. It also ships a complete Hebrew
translation: press `עב` and the whole widget switches, including a genuine
right-to-left layout - labels, tiles, alignment and notifications all flip. The
activity heatmap deliberately stays left-to-right in both languages, because it
is a timeline and reads chronologically either way.

Hebrew is selected automatically only if your desktop is already Hebrew
(`LANG=he_*` on Linux, the Windows UI language on Windows); otherwise English is
the default. Your choice is remembered.

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

He behaves identically on both platforms: which pose he strikes is decided by
one shared engine, so the two builds cannot drift into being two characters.

## How the two builds fit together

One file, one set of numbers, two front ends. Everything that decides what the
widget *says* - reading the transcripts, polling `/usage`, the streak and
heatmap maths, Clawd's choice of activity - is shared. Only the drawing is
per-platform, and the file picks its toolkit at startup:

| | Linux | Windows |
|---|---|---|
| Toolkit | GTK3 (`python3-gi`) | Tkinter (ships with Python) |
| Notifications | `notify-send` | Windows toast |
| Settings | `~/.config` | `%APPDATA%` |
| Cache and icon | `~/.cache`, `~/.local/share/icons` | `%LOCALAPPDATA%` |
| Autostart | XDG autostart entry | Startup shortcut |
| Shortcuts | applications menu + desktop | Start Menu + desktop |

The Clawd icon is encoded as a PNG (and, on Windows, an ICO) by hand from the
standard library, so it can be drawn on a machine that has no image toolkit
installed at all.

## Requirements

**Linux** - GTK 3 (`python3-gi`, present by default on Ubuntu and Fedora) and
Python 3.9+. Tested on Ubuntu with GNOME under Wayland. `set_keep_above` is
honoured on X11 only; on Wayland use your compositor's "always on top" instead.

**Windows** - Windows 10 or 11 and Python 3.9+ with Tkinter, which is what the
python.org installer gives you by default (keep "tcl/tk and IDLE" ticked).
Tested on Windows 11 with Python 3.12 and Tk 8.6.13. The widget declares itself
DPI-aware and scales its whole layout, so it stays sharp at 125% and 150%.
Always-on-top just works here.

Either way, the Claude Code CLI on `PATH` gets you the real quota numbers. It is
optional: the widget works without it, minus the quota meters.

Nothing else is required. In particular there is no editor or IDE in the
picture: the widget reads the transcript files Claude Code writes, so it works
the same whether you drive Claude Code from a terminal, from an editor
extension, or not at all while it sits there showing you yesterday's numbers.

## Notes and limits

- The quota reading refreshes every five minutes, so during a heavy burst it
  can lag by a few percent. `/usage` in a session is always the live truth.
- `/usage` itself reports that its breakdown is approximate and covers only
  local sessions on this machine, not other devices or claude.ai.
- The widget reads its own logs only; it never reads message content for
  anything other than counting.
- The Windows card has square corners. Tk cannot round a window, and faking it
  would cost more than it is worth.

## License

MIT - see [LICENSE](LICENSE).

Clawd is Anthropic's mascot; the pixel rendition here is a fan tribute and this
project is not affiliated with or endorsed by Anthropic.
