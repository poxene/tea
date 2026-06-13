# tea

Quality-of-life addon for **WoW Classic Era**.

## Install

1. Download the latest release from [github.com/poxene/tea/releases](https://github.com/poxene/tea/releases)
2. Unzip into your AddOns folder:
   ```
   World of Warcraft/_classic_era_/Interface/AddOns/
   ```
3. You should end up with `Interface/AddOns/tea/tea.toc`
4. Enable **tea** on the character select AddOns screen, then `/reload`

## Features

- **Options** — `/tea` opens a draggable settings window
- **Minimap button** — click to open options; drag to move; right-click to hide
- **Tooltip extras** — vendor price, item ID, item level, required level, equip slot, item type, max stack, tracked-item marker; optional Shift-only mode
- **Sell junk** — **Sell Junk** button on the merchant window; `/tea sell`; optional auto-sell grey items on vendor open (off by default)
- **Repair warning** — warns at vendors when gear is below 35% durability, with repair cost
- **Item tracking** — track items by ID; colored borders in bags; per-item colors
- **teaBag** — combined bag window (inventory, ammo, soul shards, special items, equipped bags bar); replaces default bags; greys out junk icons; adjustable columns, slot size, and padding; opens at vendors when needed
- **Resource bars** — floating health and power bars; drag to move; resize from corner; lock position and size

## Commands

| Command | Description |
|---------|-------------|
| `/tea` | Open options |
| `/tea help` | List commands |
| `/tea status` | Show toggles |
| `/tea bag` | Toggle teaBag |
| `/tea sell` | Sell grey items at vendor |
| `/tea track <id>` | Track an item |
| `/tea untrack <id>` | Untrack an item |
| `/tea track list` | List tracked items |
| `/tea minimap` | Show minimap button |
| `/tea tooltip on\|off` | Toggle tooltip extras |
| `/tea junk on\|off` | Toggle auto-sell grey |
| `/tea repair on\|off` | Toggle repair warning |
