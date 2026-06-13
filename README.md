# tea

Quality-of-life addon for **WoW Classic Era**.

## Install (dev)

Symlink this repo into your AddOns folder:

```bash
chmod +x scripts/link-addon.sh
./scripts/link-addon.sh
```

Then enable **tea** on the character select AddOns screen and `/reload` in-game.

## Features

- **Tooltip extras** — vendor sell price (per-item and stack) and item ID on tooltips
- **Sell grey** — merchant frame button plus optional auto-sell on vendor open
- **One bag** — combined bag view for all inventory slots
- **Item tracking** — highlight tracked item IDs with a colored border in bags

## Commands

| Command | Description |
|---------|-------------|
| `/tea` | Open the options window |
| `/tea help` | Show slash commands |
| `/tea status` | Show module toggles |
| `/tea tooltip on\|off` | Toggle tooltip extras |
| `/tea junk on\|off` | Toggle auto-sell grey at vendors |
| `/tea repair on\|off` | Toggle repair warning |
| `/tea track <id>` | Track an item by ID |
| `/tea untrack <id>` | Stop tracking an item |
| `/tea track list` | List tracked items |
| `/tea bag` | Toggle the combined bag window |
| `/tea sell` | Sell grey items at the current merchant |
| `/tea reload` | Reload the UI |

Auto-sell grey is **off by default**. Use the **Sell Grey** button on the merchant window, `/tea sell`, or `/tea junk on` for automatic selling.

## Development

- Edit Lua files here, then `/reload` in WoW.
- Enable script errors: `/console scriptErrors 1`
- Update `## Interface:` in `tea.toc` when Blizzard patches Classic Era (check another up-to-date addon if load fails).

## Project layout

```
tea.toc
Core/
  Util.lua
  Config.lua
  Track.lua
  Options.lua
  Slash.lua
  Init.lua
Modules/
  TooltipExtras.lua
  VendorTrash.lua
  RepairWarning.lua
  ItemTrack.lua
  OneBag.lua
```
