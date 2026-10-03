# Floatie Farm 🎈

Roll the Pump to inflate balloon-animal Floaties, send them down the conveyor
to your base, and let them earn Air. Spend Air on better Pumps (more luck),
upgrades and Level Ups; rebirth for permanent boosts; collect the Index;
trade with friends.

## Play it in 2 minutes
1. Install **Roblox Studio** (free) and log in.
2. Open **StealAFloatie.rbxlx** (File > Open from File), or the published place.
3. Press **Play**. The map, bases, Pump Shop and HUD all build themselves when the game starts.
4. To test trading, open the **Test** tab, set **Clients** to 2 and click **Start**.

## Test commands (type in chat while testing in Studio)
| Command | What it does |
|---|---|
| `;air 1000000` | adds Air |
| `;give Dragonflate Rainbow 50` | spawns a Floatie (mutation and level optional) |
| `;event GoldenHour` | starts an event (HeliumRain, GoldenHour, Thunderstorm, SecretSkies, LuckyBreeze) |
| `;rolls 1000` | sets your total rolls (trading unlocks at 1,000) |
| `;potion Luck 3` | adds potions (Luck, Cash, Mutation) |
| `;tokens 10` `;gems 10` `;jackpot 2` | Grade Tokens, Trait Gems, Jackpot Rolls |
| `;level 50` | sets every Floatie you own to that level |
| `;rebirths 3` | sets your rebirth count |
| `;pump 6` | owns every Pump up to that tier and equips it |
| `;buy QuadLuck` | acts as if a pass / product was bought (any GamePasses or DevProducts name, StarterPack, Offer2..Offer5, Upgrade_luck) |
| `;wipe` | (Studio only) start over as a brand-new player |

## Before you publish
- File > **Publish to Roblox**, then Game Settings > Security > **Enable Studio Access to API Services** so saving works in Studio.
- Game Settings > Places > **Max Players = 8** (there are 8 bases).
- Create the game passes and developer products on create.roblox.com and paste their IDs into `src/shared/ConfigParts/Robux.luau` (every `id = 0` is a placeholder; until then purchases only work through `;buy`).
- Put your Roblox UserId in `Config.AdminUserIds`.

## Economy (re-tuned in v1.1.0)
Numbers live in `src/shared/ConfigParts/Floaties.luau` (odds), `Rolling.luau` (Pumps) and `Progression.luau` (levels, upgrades, rebirth).
They were tuned with a simulation of a free player on Auto Roll who claims Daily and Playtime rewards, drinks potions,
uses Jackpot Rolls, Grade Tokens and Trait Gems, and saves for the next Pump. Expected pace (median play time; "days" = days of PLAY time):

| Milestone | Time |
|---|---|
| First Rare / Epic | ~1 min / ~6 min |
| Pump 3 / Pump 4 | ~25 min / ~1.5 h |
| First Legendary | ~1 h (often the 60-minute Jackpot Roll) |
| First rebirth | ~3 h |
| Pump 5 / first Mythic | ~5.5 h / ~7 h |
| Pump 6 / first Divine | ~14 h / ~20 h |
| Pump 7 / Pump 8 | ~36 h / ~57 h |
| First Celestial | ~5 days |
| First Cosmic | ~10 days |
| Pump 12 (the last) | ~28 days |
| First Secret | ~35 days, and some players need much longer (near impossible, but possible) |

Rules of thumb when changing them:
- Odds climb about x1.65 per Floatie (x12 per rarity), from 1 in 2 to 1 in 100B, like Anime Dice's "1 in 24B" units.
- Pump luck grows slowly (x1 to x200); prices were fitted so each Pump is a real goal.
- Luck upgrade: +5% per level, max 40 (x3). There is no Conveyor Luck upgrade any more: mutations only come from their base chances, Mutation potions and Helium Rain.
- A Level Up costs `Floatie income x 100 x 1.08^(level-1)`, so leveling pays back in about the same time for every Floatie.
- Rebirth takes ALL your Air (at least the cost); Floaties, Pumps and upgrades stay. Costs: 1.5B, 100B, 4T, 50T, 310T, 2.1Qa, 7.7Qa, 23Qa, then x3 each. Each one gives +50% cash, +10% luck and +2 slots (up to +6).
- Mythic and better pulls (and Legendary+ from a Jackpot Roll) are announced in the server chat, never on screen. The HIDE button turns off every roll popup.
- If you change Floatie incomes or odds, re-check these times: the whole curve depends on them.
- Re-check with the simulator (Python 3, no extra packages): `python tools/econ_sim.py 200 8` plays 8 free players for 200 play-hours and prints when they reach each milestone. Its defaults copy the game's numbers, so update them with ConfigParts. `tools/econ_fit.py` re-fits Pump prices and rebirth costs to target times.

## Where things are
| Folder | In Studio | Job |
|---|---|---|
| `src/shared/Config.luau` + `ConfigParts/` | `ReplicatedStorage/Shared` | **Edit these for updates**: Floaties, Pumps, prices, upgrades, rewards, codes, Robux products, trading |
| `src/shared/Formulas.luau` | `ReplicatedStorage/Shared/Formulas` | income, level cost, sell value, upgrade and rebirth prices (used by server and client) |
| `src/shared/FloatieModel.luau`, `PumpModel.luau` | `ReplicatedStorage/Shared` | build the balloon-animal and Pump models from shapes (no 3D modeling) |
| `src/GameServer.server.luau` | `ServerScriptService/GameServer` | starts everything |
| `src/server/` | `ServerScriptService/Server` | Rolling, Floaties, Bases, Economy, Upgrades, Rebirth, Index, Rewards, Potions, Reroll, Shop, Trading, Events, DataService (saving), Sync (client copy of the save), Admin, MapBuilder |
| `src/client/ClientMain/` | `StarterPlayer/StarterPlayerScripts/ClientMain` | Kit (UI toolkit), HUD and every panel (Backpack, Index, Pump Shop, Upgrades, Rebirth, Rewards, Shop, Trade, ...), roll and conveyor effects, tutorial |

`CarryBox`, `Darts` and `Knockback` in `ClientMain` are left over from Steal a Floatie and are no longer used.
`Art/` holds the game icon and thumbnail for the Roblox page. `tools/` holds the economy simulator (not part of the game).

## Editing with Rojo
1. In PowerShell: `cd "C:\Users\AIAN\Desktop\Roblox Games"` then `rojo serve`.
2. In Studio, Plugins > Rojo > Connect.
3. Edit scripts in VS Code (not Studio's script editor). Saves appear in Studio instantly.
4. When something works, commit and push with GitHub Desktop.
