# Lazynator

<img src="assets/spacey/spacey-4x.png" alt="Spacey, a green robot sloth hanging from a space bar" width="312">

Learn LazyVim keys in your real Neovim. Made for Omarchy. Works with any LazyVim.

Spacey, a lazy robot sloth that lives on your space bar, teaches you the LazyVim keys in two ways:

- **Lessons.** Pick a group. Spacey shows 3-5 keys. You press each one for real.
  A key counts only if its keymap really fired. Typing the `:` command does not count.
- **Nudges.** Do something the slow way (type `:bd`, click a buffer tab) and a small hint shows up:
  `Next time: [Space] [b] [d]`.

Both feed one list. Each key is **new**, **learning** or **learned**:

- **Done:** you pressed the key for real once in a lesson. Done keys do not come back in new rounds.
- **Learned:** you pressed it for real **5 times in a row**, with no slow way in between.
  One lesson round is one press. The rest comes from review rounds and from using the key while you work:
  every real press counts, also outside lessons. Taking the slow way (like `:bd`) starts the count again.
  Change the 5 with `opts = { learned_after = 3 }`.

## Install

Omarchy: make one file, `~/.config/nvim/lua/plugins/lazynator.lua`:

```lua
return { "smanookian/lazynator.nvim", opts = {} }
```

Restart Neovim. Other LazyVim setups: the same line in your plugin specs.

Needs Neovim 0.11.2 or newer.

**Best terminal: Ghostty** (Omarchy's default). In Ghostty, Kitty and WezTerm you see Spacey as a real picture.
In Foot and Alacritty you see a small text drawing instead, because those terminals can't show pictures.
Everything else works the same in every terminal.

The boxes grow with your terminal: small terminals (under 30 rows) get a compact box with a 4-row Spacey,
medium ones a 5-row Spacey, large ones (50+ rows) a 9-row Spacey with more space. Resize, and they follow.

## Commands

| Command | What it does |
| --- | --- |
| `:Lazynator` | Menu. Press a number to start a lesson. |
| `:Lazynator lesson <group>` | Start a lesson: `buffers`, `files`, `search`, `git`, `code`, `toggles`, `windows`. |
| `:Lazynator stats` | Learned / learning / new, per group. |
| `:Lazynator skip` | Skip the current key in a lesson. |
| `:Lazynator stop` | End the lesson now. |
| `:Lazynator reset` | Start over: forget all progress. Asks first. |
| `:Lazynator reset <group>` | Forget the progress of one group, e.g. `:Lazynator reset buffers`. |

## Lessons

- A lesson opens in a new tab. It uses scratch buffers, or a small practice project
  that is deleted when the lesson ends. Your files are not touched.
- When it ends, everything goes back: your tab, your buffers (even if you pressed
  "Delete Other Buffers"), toggles and your colorscheme.
- The keycaps light up as you type. If a key opens something (a picker, the file tree, Lazygit), just press
  the next key: Spacey closes it first, then runs your key.
- A lesson is done in rounds of up to 5 keys. A key you pressed for real in a lesson is **done** and
  does not come back. After a round, the menu opens with the next round selected: press `Enter` to go on.
- When all keys of a group are done, the group shows **✓ finished**. Starting it again gives a **review**
  of the keys you have not learned yet. `:Lazynator reset <group>` makes the keys new again.
- Keys come from your config, read live. Change a keymap and the next lesson shows it. No restart.
  Keys that are not in your config are skipped.

## Nudges

Slow ways Spacey sees:

- Typed commands that have a key: `:bd` → `Space b d`, `:Neotree` → `Space e`,
  `:Telescope find_files` → `Space f f`, `:LazyGit` → `Space g g`, `:w` → `Ctrl s`, and more.
  A command also matches when it is the right-hand side of one of your keymaps.
- Mouse clicks on a buffer tab (`Shift h` / `Shift l`, or `Space ,`), a tab's close icon (`Space b d`),
  and the file tree (`Space e`; opening a file from it: `Space Space`). Works with neo-tree and the snacks explorer.

A hint for the same key shows at most once every 10 minutes. The slow way still resets that key's count.

## Options

These are the defaults:

```lua
return {
  "smanookian/lazynator.nvim",
  opts = {
    mascot = "auto", -- "auto": Spacey as a picture in Ghostty, Kitty or WezTerm; "text": always the text drawing
    learned_after = 5, -- real presses in a row for "learned"
    nudge = {
      enabled = true, -- false turns all hints off
      every = 10, -- minutes between hints for the same key
      timeout = 8000, -- ms a hint stays
      skip = {}, -- keys that never get a hint, e.g. { "<C-s>" }
      mouse = true, -- hints for mouse clicks
    },
  },
}
```

## Privacy and speed

- No network. No telemetry.
- Progress is a small JSON file: `~/.local/share/nvim/lazynator/progress.json`
  (`stdpath("data")`). `:Lazynator reset` starts over.
- Startup cost: about 0.2 ms. The rest (about 2 ms) runs after Neovim is on screen.

## How it works

- Keymaps are read live with `nvim_get_keymap()`, buffer keymaps and which-key descriptions.
- Each key Lazynator follows is wrapped: the wrapper notes the press, then runs your original keymap.
  Wrapping is redone when plugins load, when you `:source` a file and when an LSP attaches.
- A small built-in list gives only the lesson order, the groups and the slow-way commands
  (`lua/lazynator/groups.lua`).

## GIF plan

One GIF, about 25 seconds, fresh Omarchy, Tokyo Night, terminal about 120×35:

1. Type `:bd`. The hint pops up: `Next time: [Space] [b] [d]`. (3 s)
2. `:Lazynator`, press `1` (Buffers). The lesson opens. (3 s)
3. Press `Shift l`, then `Shift h`. Keycaps light up, check marks appear. (5 s)
4. Type `:bnext` instead. "That was the slow way. It does not count." (3 s)
5. Press `Space b d`. Lesson done, Spacey sits on the bar and cheers. (4 s)
6. `:Lazynator stats`. (3 s)
7. Click a buffer tab with the mouse. `Next time: [Shift l]`. (3 s)

Record with `omarchy capture screenrecording` (stop with `--stop-recording`), make the GIF with
`gifski` (800 px wide, under 3 MB), save it as `assets/lazynator.gif` and put it at the top of this README.

## Develop

```sh
./scripts/test.sh           # headless tests, no network
./scripts/test-lazyvim.sh   # tests inside a real LazyVim (downloads the LazyVim starter)
```

CI runs both on every push (`.github/workflows/test.yml`).

## License

MIT
