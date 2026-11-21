# Xius Core

The settings and quality-of-life hub for the Xius addons on **modern World of Warcraft** and **World of Warcraft Forever**. One window holds Quality of Life, General, and every other Xius addon you have installed. Missing addons stay listed, with a link you can copy. The bag still shows only this character's gold. Hover the coins to see the rest of the account.

The window is meant to blend with the default UI.

## Features

### One settings window

- **Open it anywhere:** `/xius`, `/xiuscore`, or the minimap button.
- **Sidebar:** Threat Meter, XP & Rep, Marks Bar, Quality of Life, Flight Map, Tooltip, Max Graphics, Kill Streak, Spell Ranks, Layer Swap, and General.
- **Installed addons** are highlighted in the sidebar and open their own settings page.
- **Addons that are not installed** stay in the list in gray. Click one for a short description and a CurseForge link. Select URL highlights it so you can copy it.

### Quality of Life

- **Vendors:** Faster loot, sell gray items, and auto repair with your gold or the guild bank.
- **Training:** A Train All button at class and profession trainers.
- **Quests and travel:** Optional auto-accept and turn-in, summons, a summon sound, non-combat resurrection, and skip on the cinematic confirmation.
- **Group and social:** Whisper invites from keywords you choose, friend and guild invites, and declines for stranger duels, pet duels, and guild invites.
- **Combat and interface:** Auto-release in battlegrounds, quest levels, the quest log collapse arrow, stand and dismount, easy item destroy, hidden error text, a hidden talking head, muted mount emotes, class-colored name backgrounds, and durability on the character sheet.

### Flight Map

- High-detail continent and zone art on the flight master map.
- Smooth zoom and pan, with zone level ranges and cursor coordinates.
- Works on the Forever taxi map and the retail flight map.

### Tooltip

- Shows a player's guild under their name on the unit tooltip.
- Optional guild rank, with separate colors for your guild and other guilds.

### Account gold

- **Bag coins stay as they are.** The backpack still shows this character's gold in the normal Blizzard coins.
- **Hover the coins** for an account list: class-colored names, this character tagged You, richest first, your realm first, then a gold line and the account total.
- **General settings** turn the tooltip on or off, limit it to this realm, hide characters with no gold, or prune old characters.
- Account gold is stored in the shared `XiusUIDB` table so Forever realm shards stay merged cleanly.

### General

- **Minimap button:** Left-click opens the window. Right-click unlocks or locks movable frames. Drag moves the icon.
- **Reset Window** puts the window back in the middle of the screen.
- **Unlock Frames** in the window header does the same thing as right-clicking the minimap button.
- Smoked-glass settings window styled after Blizzard Options.

## Controls & Slash Commands

| Command / Input | Action |
| --- | --- |
| `/xius` or `/xiuscore` | Open or close the window |
| `/xius config` or `/xius options` | Open or close the window |
| `/xius qol` | Open Quality of Life |
| `/xius general` | Open General |
| `/xius threat` | Open Threat Meter |
| `/xius xp` | Open XP & Rep |
| `/xius marks` | Open Marks Bar |
| `/xius quest` | Open Quality of Life |
| `/xius graphics` | Open Max Graphics |
| `/xius streak` | Open Kill Streak |
| `/xius unlock` | Unlock or lock movable frames |
| `/xius help` | List the commands |
| Left-click the minimap button | Open or close the window |
| Right-click the minimap button | Unlock or lock movable frames |
| Drag the minimap button | Move the icon |
| Hover bag coins | Show account gold |

## Configuration

Open the window with `/xius`, `/xiuscore`, or the minimap button.

- **Quality of Life:** Vendor, training, quest, social, and combat helpers. Each one has its own checkbox.
- **General:** Minimap button, chat notices, Reset Window, and the account gold tooltip.
- **Other Xius addons:** Their pages appear here when that addon is enabled.

Quality of Life, the window, the minimap button, and account gold are saved for the account.

## More From Xius

### Xius Threat Meter - [GitHub](https://github.com/XiusTV/XiusThreatMeter) · [CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter)

A threat meter. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.

### Xius XP & Reputation Tracker - [GitHub](https://github.com/XiusTV/XiusXPTracker) · [CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)

A HUD card for level, XP, rested XP, watched faction, session rates, gold, and time-to-level.

### Xius Marks Bar - [GitHub](https://github.com/XiusTV/XiusMarksBar) · [CurseForge](https://www.curseforge.com/wow/addons/xius-marks-bar)

A raid marking bar. Click the flag for world markers or the star for target markers. Includes 5 / 10 / 20 pull timers, ready check, and role check.

### Xius Max Graphics - [GitHub](https://github.com/XiusTV/XiusMaxGFX) · [CurseForge](https://www.curseforge.com/wow/addons/xius-max-graphics)

Graphics presets for Forever and retail. Ultimate, Balance, and Defaults raise view distance, grass, shadows, water, and image clarity, with optional loot and gathering sparkles.

### Xius Kill Streak - [GitHub](https://github.com/XiusTV/XiusKillStreak) · [CurseForge](https://www.curseforge.com/wow/addons/xius-kill-streak)

A ten-tier kill streak announcer for mobs and enemy players. Each tier shows a banner, plays a call, and keeps a counter for the streak and the time left.

Their settings open from this window.

## License

Released under the [GNU General Public License v2.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and the settings window, with manual architecture, in-game verification, and maintenance by Xius.
