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
| `;give Dragonflate Ruby Huge 50` | spawns a Floatie (mutation, size and level optional, any order) |
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

## How a pull works (v1.2, copied from Anime Dice)
The full research is in `AnimeDice-notes.md` (with screenshots in `AnimeDice-screenshots/`).

- **Every pull is a copy:** a Floatie in a size with a mutation. Its odds multiply:

  | Size | Odds | Income | | Mutation | Odds | Income |
  |---|---|---|---|---|---|---|
  | Normal | x1 | x1 | | Silver | x10 | x5.4 |
  | Huge | x10 | x5.4 | | Gold | x100 | x29 |
  | Titanic | x100 | x29 | | Emerald | x1,000 | x155 |
  | | | | | Diamond | x10,000 | x830 |
  | | | | | Ruby | x100,000 | x4,500 |
  | | | | | Rainbow | x1,000,000 | x24,000 |
  | | | | | Thunder (Thunderstorm only) | x1,000 | x155 |

  A Huge Ruby Pupfloat is 1 in 2 x 10 x 100K = **1 in 2M**. Income follows the odds (multiplier ^ 0.73), and Huge / Titanic Floaties are bigger on your base.
- **Luck works like Anime Dice's:** Luck removes every copy more common than "1 in Luck", and you get one of the rest, weighted by how rare it is. So pulls land at about 1–10x your Luck, and about 1 pull in 100 is 100x rarer than it.
- **A copy's rarity comes from its odds**, not from the Floatie: a Ruby Pupfloat (1 in 200K) is Legendary. Rarities start at: Uncommon 20, Rare 250, Epic 3K, Legendary 40K, Mythic 500K, Divine 6M, Celestial 70M, Cosmic 1B, Secret 10B, **Heavenly 1T, Infinite 1Qa** (the last two only exist through sizes and mutations).
- Mutation potions (x3) and Helium Rain (x4) make mutated copies count as that much less rare, so you pull rarer mutations; Secret Skies does the same (x5) for Secret Floaties.
- **The Index** has 1,200 entries: size buttons (Normal / Huge / Titanic) across the top and mutation tabs down the side, each entry showing that version's own odds. Milestones go up to 1,000; collecting everything is out of reach.
- Auto Sell, the big reveal (Jackpot Rolls and Rare+ pulls 100x rarer than your Luck) and the chat announcements (Mythic+ pulls 1,000x rarer than your Luck, or Legendary+ from a Jackpot Roll) all use the copy's own rarity and odds. The HIDE button turns off every roll popup.

## Economy (re-tuned in v1.2)
Numbers live in `src/shared/ConfigParts/Floaties.luau` (odds), `Rolling.luau` (sizes, mutations, Pumps) and `Progression.luau` (levels, upgrades, rebirth, Index).
They were tuned with a simulation of a free player on Auto Roll who claims Daily and Playtime rewards, drinks potions,
uses Jackpot Rolls, Grade Tokens and Trait Gems, and saves for the next Pump. Expected pace (median play time; "days" = days of PLAY time):

| Milestone | Time |
|---|---|
| First Huge / first Titanic | ~30 s / ~2 min |
| First Rare / Epic / Legendary pull | ~1 min / ~3 min / ~25 min |
| Pump 3 / Pump 4 | ~25 min / ~1.5 h |
| First Diamond mutation | ~1 h |
| First rebirth | ~3 h |
| First Mythic pull | ~3 h |
| Pump 5 / first Ruby | ~5 h / ~8 h |
| First Divine pull | ~8 h |
| Pump 6 / first Rainbow | ~14 h / ~1 day |
| Pump 7 / Pump 8 | ~33 h / ~3.5 days |
| First Celestial pull | ~3.5 days |
| First Cosmic pull | ~15 days |
| Pump 12 (the last) | ~30 days |
| First Secret pull | ~40 days (26–58) |
| First Heavenly / Infinite pull | never seen in 1,500 simulated hours (near impossible) |

Rules of thumb when changing them:
- Floatie odds climb about x1.65 per Floatie, from 1 in 2 to 1 in 100B; every Floatie's rarity must match its odds (Config checks this when it loads).
- Pump luck climbs about x1.6 per pump (x1 to x200). Anime Dice's dice double, but with 24 sizes/mutations per Floatie, doubling made rare pulls come far too soon.
- Luck upgrade: +5% per level, max 40 (x3). There is no Conveyor Luck upgrade.
- A Level Up costs `Floatie income x 100 x 1.08^(level-1)` (income includes size and mutation), so leveling pays back in about the same time for every Floatie.
- Rebirth takes ALL your Air (at least the cost); Floaties, Pumps and upgrades stay. Costs: 9.6B, 330B, 6.4T, 65T, 430T, 1.9Qa, 9Qa, 21Qa, then x3 each. Each one gives +50% cash, +10% luck and +2 slots (up to +6).
- If you change odds, incomes, sizes or mutations, re-check these times: the whole curve depends on them.
- **Simulator** (Python 3, no extra packages): `python tools/econ_sim.py 200 8` plays 8 free players for 200 play-hours and prints when they reach each milestone. Its defaults copy the game's numbers, so update them with ConfigParts. `tools/econ_fit.py` re-fits Pump prices and rebirth costs to target times.
- **Checks without Studio:** `python tools/check.py` finds syntax errors and misspelled names in every script and runs the logic tests in `tools/tests/` (Config, odds, rarities, the pull). Server and client scripts still need a playtest: copy `tools/studio-tests/Stage18Test.server.luau` into `src/server/`, press Play, read the `[T18]` lines, then delete it.

## Where things are
| Folder | In Studio | Job |
|---|---|---|
| `src/shared/Config.luau` + `ConfigParts/` | `ReplicatedStorage/Shared` | **Edit these for updates**: Floaties, Pumps, prices, upgrades, rewards, codes, Robux products, trading |
| `src/shared/Formulas.luau` | `ReplicatedStorage/Shared/Formulas` | the pull (`pickCopy`), a copy's odds / rarity / name, income, level cost, sell value, upgrade and rebirth prices (used by server and client) |
| `src/shared/FloatieModel.luau`, `PumpModel.luau` | `ReplicatedStorage/Shared` | build the balloon-animal and Pump models from shapes (no 3D modeling) |
| `src/GameServer.server.luau` | `ServerScriptService/GameServer` | starts everything |
| `src/server/` | `ServerScriptService/Server` | Rolling, Floaties, Bases, Economy, Upgrades, Rebirth, Index, Rewards, Potions, Reroll, Shop, Trading, Events, DataService (saving), Sync (client copy of the save), Admin, MapBuilder |
| `src/client/ClientMain/` | `StarterPlayer/StarterPlayerScripts/ClientMain` | Kit (UI toolkit), HUD and every panel (Backpack, Index, Pump Shop, Upgrades, Rebirth, Rewards, Shop, Trade, ...), roll and conveyor effects, tutorial |

`Art/` holds the game icon and thumbnail for the Roblox page. `tools/` holds the economy simulator, the no-Studio checks and the Studio test scripts (not part of the game).

## Editing with Rojo
1. In PowerShell: `cd "C:\Users\AIAN\Desktop\Roblox Games"` then `rojo serve`.
2. In Studio, Plugins > Rojo > Connect.
3. Edit scripts in VS Code (not Studio's script editor). Saves appear in Studio instantly.
4. When something works, commit and push with GitHub Desktop.
