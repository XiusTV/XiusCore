# Xius Core

The settings and quality-of-life hub for the Xius UI suite on **modern World of Warcraft** and **World of Warcraft Forever**. One window holds Quality of Life, General, and every other Xius addon you have installed. Missing addons stay listed, with a link you can copy. The bag still shows only this character's gold. Hover the coins to see the rest of the account.

Near-black panels and thin gold text keep it with the rest of the Xius set.

## Features

### One settings window

- **Open it anywhere:** `/xius`, `/xiuscore`, or the minimap button.
- **Always the same list:** Threat Meter, XP & Rep, Marks Bar, Quality of Life, Max Graphics, Kill Streak, Quest Log, and General stay in that order.
- **Installed addons** use bright gold in the sidebar and open their own settings page.
- **Addons that are not installed** stay in the list in muted gray. Click one for a short description and a CurseForge link. Select URL highlights it so you can copy it.

### Quality of Life

- **Vendors:** Faster loot, sell gray items, and auto repair with your gold or the guild bank.
- **Training:** A Train All button at class and profession trainers, and action bars that move up to the highest rank you know.
- **Quests and travel:** Optional auto-accept and turn-in, summons, a summon sound, non-combat resurrection, and skip on the cinematic confirmation.
- **Group and social:** Whisper invites from keywords you choose, friend and guild invites, and declines for stranger duels, pet duels, and guild invites.
- **Combat and interface:** Auto-release in battlegrounds, quest levels, stand and dismount, easy item destroy, hidden error text, a hidden talking head, muted mount emotes, class-colored name backgrounds, and durability on the character sheet.

### Account gold

- **Bag coins stay as they are.** The backpack still shows this character's gold in the normal Blizzard coins.
- **Hover the coins** for an account list: class-colored names, this character tagged You, richest first, your realm first, then a gold line and the account total.
- **General settings** turn the tooltip on or off, limit it to this realm, hide characters with no gold, or prune old characters.

### General

- **Minimap button:** Left-click opens the window. Drag moves the icon.
- **Reset Window** puts the window back in the middle of the screen.
- **Shared keybindings** for the Marks Bar wheels and marks are grouped under Xius Core in the Key Bindings menu.

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
| `/xius quest` | Open Quest Log |
| `/xius graphics` | Open Max Graphics |
| `/xius streak` | Open Kill Streak |
| `/xius help` | List the commands |
| Left-click the minimap button | Open or close the window |
| Drag the minimap button | Move the icon |
| Hover bag coins | Show account gold |

## Configuration

Open the window with `/xius`, `/xiuscore`, or the minimap button.

- **Quality of Life:** Vendor, training, quest, social, and combat helpers. Each one has its own checkbox.
- **General:** Minimap button, chat notices, Reset Window, and the account gold tooltip.
- **Other Xius addons:** Their pages appear here when that addon is enabled.

Quality of Life, the window, the minimap button, and account gold are saved for the account.

## Installation

1. Download the latest release `.zip` (or use **Code → Download ZIP** on this page).
2. Extract the `XiusCore` folder into the addon directory for the client you play:
   - Forever: `World of Warcraft\_forever_\Interface\AddOns`
   - Retail: `World of Warcraft\_retail_\Interface\AddOns`
   If the extracted folder is named `xiuscore-main`, rename it to `XiusCore`.
3. Launch the game, confirm Xius Core is checked in your AddOns menu, and run `/reload`.
4. Type `/xius`.

**Compatibility:** Modern World of Warcraft and World of Warcraft Forever. Pure Lua 5.1. The other Xius addons are optional. Each one adds its own page when it is enabled.

## File Overview

| File | Purpose |
| --- | --- |
| `XiusCore.toc` | Addon manifest, saved variables, and load order |
| `XiusCore_Forever.toc` | Forever manifest |
| `Bindings.xml` | Shared Marks Bar keybindings |
| `Libs/XiusUISettingsLib.lua` | Shared settings window used by the other Xius addons |
| `Config/Builtin.lua` | Quality of Life and General pages |
| `Modules/QualityOfLife.lua` | Vendor, quest, social, and combat helpers |
| `Modules/AccountGold.lua` | Account gold memory and the bag-coin tooltip |
| `Core/Minimap.lua` | Minimap button |

## More From Xius

**Xius Threat Meter**: A clean, lightweight threat meter. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.
[GitHub](https://github.com/XiusTV/XiusThreatMeter) · [CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter)

**Xius XP & Reputation Tracker**: A compact HUD card that replaces the default XP and reputation bars with a single movable panel: level, XP, rested, watched faction, session rates, gold, and time-to-level.
[GitHub](https://github.com/XiusTV/XiusXPTracker) · [CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)

**Xius Marks Bar**: A compact raid marking bar. Click the flag for world markers or the star for target markers, with 5 / 10 / 20 pull timers, ready check, and role check built in.
[GitHub](https://github.com/XiusTV/XiusMarksBar) · [CurseForge](https://www.curseforge.com/wow/addons/xius-marks-bar)

**Xius Max Graphics**: Pick-and-choose graphics upgrades for Forever and retail. Ultimate, Balance, and Defaults presets push view distance, grass, shadows, water, and image clarity past the normal graphics menu, with optional loot and gathering sparkles.
[GitHub](https://github.com/XiusTV/XiusMaxGFX)

**Xius Kill Streak**: A ten-tier kill streak announcer for mobs and enemy players. Each new tier shows a banner and plays a call, with a small counter for the current streak and the time left to keep it going.
[GitHub](https://github.com/XiusTV/XiusKillStreak)

**Xius Quest Collapser**: An arrow on the line between the world map and the quest log. Click it to fold the list away, then click it again to open the list.
[GitHub](https://github.com/XiusTV/XiusQuestCollapser) · [CurseForge](https://www.curseforge.com/wow/addons/xius-quest-collapser)

All Xius addons share the same clean, dark gold style for a unified UI. Their settings open from this window.

## License

Released under the [GNU General Public License v2.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and the settings window, with manual architecture, in-game verification, and maintenance by Xius.
