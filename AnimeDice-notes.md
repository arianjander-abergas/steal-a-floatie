# Anime Dice — rarity system notes

Game: [UPD 6] Anime Dice — https://www.roblox.com/games/113290951185459/Anime-Dice
Captured: Sun 4 Oct 2026, about 12:55–13:25 and 14:02–14:35 (PH time), in the Roblox Player on this PC.
Nothing was bought (Robux or in-game cash) and no purchase prompt was opened.

**Status:** all five items are covered, plus the Grades and Traits odds (section 7, from your screenshots of those menus). Gap: dice **prices** aren't shown in the game, because every die is already owned.

Notation: the game uses short-scale suffixes: k (thousand), m (million), b (billion), t (trillion), qd (quadrillion), qi (quintillion), sx (sextillion), sp (septillion). "1 in X" values are copied exactly as the game shows them. The game rounds them, e.g. it shows Maheto as "1 in 16k" in the normal tab but as "1 in 165k" in the Huge tab.

Screenshots are in `AnimeDice-screenshots/` next to this file (list at the bottom).

---

## Key takeaways (for designing your own system)

1. **Odds stack by multiplication.** Final odds = base odds × size multiplier × mutation multiplier. A placed unit in the world proves it: **"Emerald / Huge Eskanar / Divine / 1 in 7.7t"**. That is 775m (Eskanar) × 10 (Huge) × 1,000 (Emerald) = 7.75t.
2. **Size multipliers:** Huge = ×10, Titanic = ×100 (the Huge and Titanic Index tabs).
3. **Mutation multipliers.** Order in the Index column, top to bottom: Silver ×10, Gold ×100, Emerald ×1,000, Diamond ×10,000, Ruby ×100,000, Rainbow ×1,000,000. All 640 size/mutation cells (8 tabs × 80 units) match base × multiplier, allowing for the game's rounding. Six cells were partly covered in my capture; they are marked * in the table.
4. **The rarity tier is recalculated from the final odds, not kept from the base unit.** Krillan (1 in 11) is Common, but Huge Krillan (1 in 110) is Uncommon. Naroto (1 in 2) is Common, but Ruby Naroto (1 in 200k) is Epic. Card border colours change to match.
5. **Tier boundaries look like powers of ten** (see the tier table below). From Legendary up, each tier covers about ×100 in odds and holds 8 units, so each unit is about **×1.8 rarer** than the one before it (median step ×1.81, range ×1.75–×1.875 from Kaidon onward).
6. **Income grows more slowly than rarity.** Fitting the 74 discovered base units gives income ≈ odds^0.73 (log10 income = 0.727 × log10 odds − 0.03). A unit 10× rarer pays about 5.3× more.
7. **Luck = die × rebirth × upgrades, exactly.** The clover in the HUD reads **x19.7t**. That is the equipped Radiant die (5,000,000,000x) × Rebirth 40x × (1 + 43.5 from Luck I–XIV + 54 from Fortune I–XII) = 5b × 40 × 98.5 = 19.7t. Potions in the backpack were not active.
8. **80 base units** (74 discovered, 6 locked) span 10 tiers, Common to Secret I. Two higher tiers, **Secret II** and **Heavenly**, appear only once size/mutation multipliers push a unit past 100qi / 100sx. Their names come from the dice shop tags in matching colours. The Index shows locked entries as black silhouettes, but their "1 in X" stays visible.
9. **Dice ladder:** 29 dice from Normal 2x to Radiant 5,000,000,000x. Each die is about ×2–2.5 the one before. Dice reuse the unit rarity names (1–3 dice per tier).
10. **Income follows the final odds.** Titanic cards earn about ×28 their base unit (Kaidon $139k/s → Titanic Kaidon $3.9m/s). That is 100^0.73, the same curve as takeaway 6.
11. **Grades and Traits are separate rolls on top of a unit**, and their menus show odds as **% chances** instead of "1 in X". Grades cost 1 Gem per roll and multiply income only: D ×1.1 at 43.1% up to ∞ ×100 at 0.001%. Traits cost 1 Trait Reroll per roll. They come in 3 stat families (Money, Damage, Health), each with I/II/III at 24.5% / 6.8% / 1.5% for ×1.2 / ×1.5 / ×2. Above those are 6 all-stat traits, from Samurai ×3 (0.67%) to Paradox ×57.5 (0.0022%). Neither changes a unit's "1 in X".

---

## 1. Index

### How the Index is laid out
- Left buttons: **None / Huge / Titanic** (size filter).
- Right column: **mutation filter** icons, top to bottom: red ✖ (= no mutation; it shows the same numbers as the default view), Silver ingot, Gold ingot, Emerald, Diamond, Ruby, Rainbow. The column scrolls; Rainbow is hidden below Ruby until you scroll it.
- Size and mutation filters combine. **Huge + Silver** shows base × 100, e.g. 22qd → 2.2qi and 1.4qi → 140qi (screenshot 38).
- Each card shows the portrait (black silhouette if locked) and "1 in X". In mutation tabs, a small mutation badge sits in the corner.
- Hovering a discovered card shows a tooltip: **Name / Rarity / Level 1 / $income/s / 1 in X**. Locked cards show no tooltip.
- In the normal tab the first row is ordered Naroto (2), Ginyou (4), Ichiga (3), Aizan (6). Every other tab sorts strictly by odds. The tables below use odds order.

### 1a. Base units (None tab, no mutation), from tooltips

| # | Unit | Rarity | Income (Lv 1) | 1 in X | Locked? |
|---|---|---|---|---|---|
| 1 | Naroto | Common | $1/s | 2 |  |
| 2 | Ichiga | Common | $2/s | 3 |  |
| 3 | Ginyou | Common | $2/s | 4 |  |
| 4 | Aizan | Common | $3/s | 6 |  |
| 5 | Krillan | Common | $5/s | 11 |  |
| 6 | Inasuke | Common | $7/s | 15 |  |
| 7 | Tien | Common | $8/s | 20 |  |
| 8 | Nezuka | Common | $11/s | 28 |  |
| 9 | Pikolo | Common | $13/s | 38 |  |
| 10 | Friza | Common | $17/s | 52 |  |
| 11 | Kakeshi | Common | $27/s | 95 |  |
| 12 | Perfect Zell | Uncommon | $34/s | 130 |  |
| 13 | Zenitsa | Uncommon | $42/s | 175 |  |
| 14 | Tanjuro | Uncommon | $53/s | 240 |  |
| 15 | Todoraki | Uncommon | $66/s | 325 |  |
| 16 | Bakuga | Uncommon | $83/s | 450 |  |
| 17 | Deko | Uncommon | $132/s | 850 |  |
| 18 | Hasoka | Rare | $170/s | 1.2k |  |
| 19 | Zaro | Rare | $219/s | 1.7k |  |
| 20 | Levy | Rare | $282/s | 2.4k |  |
| 21 | Goko | Rare | $371/s | 3.5k |  |
| 22 | Super Saiyen | Rare | $480/s | 5k |  |
| 23 | Todoh | Rare | $851/s | 11k |  |
| 24 | Maheto | Rare | $1.1k/s | 16k |  |
| 25 | Madera | Rare | $1.5k/s | 25k |  |
| 26 | Sakuna | Rare | $2k/s | 38k |  |
| 27 | Gujo | Rare | $2.8k/s | 57k |  |
| 28 | Namee | Rare | $3.7k/s | 85k |  |
| 29 | Usop | Epic | $4.9k/s | 125k |  |
| 30 | Enol | Epic | $9.1k/s | 290k |  |
| 31 | Buu | Epic | $12k/s | 450k |  |
| 32 | Vegata | Epic | $17k/s | 700k |  |
| 33 | Yuju | Epic | $23k/s | 1.1m |  |
| 34 | Jogu | Epic | $33k/s | 1.7m |  |
| 35 | Mahorago | Epic | $46k/s | 2.7m |  |
| 36 | Itacha | Epic | $66k/s | 4.5m |  |
| 37 | Kaidon | Legendary | $139k/s | 12m |  |
| 38 | Loffy | Legendary | $213k/s | 22m |  |
| 39 | Saytama | Legendary | $324k/s | 40m |  |
| 40 | Bills | Legendary | $512k/s | 75m |  |
| 41 | Obita | Legendary | $784k/s | 135m |  |
| 42 | Killer | Legendary | $1.1m/s | 240m |  |
| 43 | Gon | Legendary | $1.8m/s | 430m |  |
| 44 | Eskanar | Legendary | $2.7m/s | 775m |  |
| 45 | Asto | Mythical | $4.2m/s | 1.4b |  |
| 46 | Jin-woo | Mythical | $6.5m/s | 2.5b |  |
| 47 | Angel | Mythical | $9.9m/s | 4.5b |  |
| 48 | Ul Goko | Mythical | $15m/s | 8b |  |
| 49 | Arin | Mythical | $23m/s | 14b |  |
| 50 | Ginus | Mythical | $35m/s | 26b |  |
| 51 | Android 17 | Mythical | $54m/s | 47b |  |
| 52 | Mikasu | Mythical | $83m/s | 85b |  |
| 53 | Beast Gokan | Divine | $126m/s | 150b |  |
| 54 | Denjo | Divine | $193m/s | 270b |  |
| 55 | Okarin | Divine | $298m/s | 490b |  |
| 56 | Ryek | Divine | $456m/s | 880b |  |
| 57 | Dio | Divine | $704m/s | 1.6t |  |
| 58 | Isago | Divine | $1b/s | 2.9t |  |
| 59 | Mobb | Divine | $1.6b/s | 5.2t |  |
| 60 | Thorfyn | Divine | $2.5b/s | 9.4t |  |
| 61 | Kafko | Exotic | $3.9b/s | 17t |  |
| 62 | Kiritoe | Exotic | $6b/s | 31t |  |
| 63 | Gilgamash | Exotic | $9.2b/s | 56t |  |
| 64 | Katakury | Exotic | $14b/s | 100t |  |
| 65 | Utah | Exotic | $21b/s | 180t |  |
| 66 | Rimero | Exotic | $33b/s | 330t |  |
| 67 | Mazun | Exotic | $51b/s | 600t |  |
| 68 | Almait | Celestial | $80b/s | 1.1qd |  |
| 69 | Garuo | Celestial | $123b/s | 2qd |  |
| 70 | Bruly | Celestial | $189b/s | 3.6qd |  |
| 71 | Suffer | Celestial | $291b/s | 6.5qd |  |
| 72 | ??? (locked) | (celestial-style border) | — | 12qd | **locked** |
| 73 | Griffin | Celestial | $705b/s | 22qd |  |
| 74 | Bezerk | Celestial | $1t/s | 40qd |  |
| 75 | ??? (locked) | (celestial-style border) | — | 72qd | **locked** |
| 76 | Strike | Secret I | $2.5t/s | 130qd |  |
| 77 | ??? (locked) | (red border, Secret-tier) | — | 235qd | **locked** |
| 78 | ??? (locked) | (red border, Secret-tier) | — | 420qd | **locked** |
| 79 | ??? (locked) | (red border, Secret-tier) | — | 760qd | **locked** |
| 80 | ??? (locked) | (red border, Secret-tier) | — | 1.4qi | **locked** |

Count per tier: Common 11, Uncommon 6, Rare 11, Epic 8, Legendary 8, Mythical 8, Divine 8, Exotic 7, Celestial 8 (2 still locked, with celestial-style borders), Secret I 5 (Strike plus 4 locked). Griffin (#73) was locked in the first session and discovered by the second.

### 1b. Every tab — "1 in X" for every unit, locked entries included

Columns = Index tabs. Size tabs were read with no mutation selected. Mutation tabs were read with size = None.
`*` = the number was partly covered by a pop-up in my capture. The value shown fits the tab's multiplier and the neighbouring cards.

| # | Unit | None | Huge (×10) | Titanic (×100) | Silver (×10) | Gold (×100) | Emerald (×1k) | Diamond (×10k) | Ruby (×100k) | Rainbow (×1m) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Naroto | 2 | 20 | 200 | 20 | 200 | 2k | 20k | 200k | 2m |
| 2 | Ichiga | 3 | 30 | 300 | 30 | 300 | 3k | 30k | 300k | 3m |
| 3 | Ginyou | 4 | 40 | 400 | 40 | 400 | 4k | 40k | 400k | 4m |
| 4 | Aizan | 6 | 60 | 600 | 60 | 600 | 6k | 60k | 600k | 6m |
| 5 | Krillan | 11 | 110 | 1.1k | 110 | 1.1k | 11k | 110k | 1.1m | 11m |
| 6 | Inasuke | 15 | 150 | 1.5k | 150 | 1.5k | 15k | 150k | 1.5m | 15m |
| 7 | Tien | 20 | 200 | 2k | 200 | 2k | 20k | 200k | 2m | 20m |
| 8 | Nezuka | 28 | 280 | 2.8k | 280 | 2.8k | 28k | 280k* | 2.8m | 28m |
| 9 | Pikolo | 38 | 380 | 3.8k | 380 | 3.8k | 38k | 380k | 3.8m | 38m |
| 10 | Friza | 52 | 520 | 5.2k | 520 | 5.2k | 52k | 520k | 5.2m | 52m |
| 11 | Kakeshi | 95 | 950 | 9.5k | 950 | 9.5k | 95k | 950k | 9.5m | 95m |
| 12 | Perfect Zell | 130 | 1.3k | 13k | 1.3k | 13k | 130k | 1.3m | 13m | 130m |
| 13 | Zenitsa | 175 | 1.7k | 17k | 1.7k | 17k | 175k | 1.7m | 17m | 175m |
| 14 | Tanjuro | 240 | 2.4k | 24k | 2.4k | 24k | 240k | 2.4m | 24m | 240m |
| 15 | Todoraki | 325 | 3.2k | 32k | 3.2k | 32k | 325k | 3.2m | 32m | 325m |
| 16 | Bakuga | 450 | 4.5k | 45k | 4.5k | 45k | 450k | 4.5m* | 45m* | 450m |
| 17 | Deko | 850 | 8.5k | 85k | 8.5k | 85k | 850k | 8.5m | 85m | 850m |
| 18 | Hasoka | 1.2k | 12k | 120k | 12k | 120k | 1.2m | 12m | 120m | 1.2b |
| 19 | Zaro | 1.7k | 17k | 170k | 17k | 170k | 1.7m | 17m | 170m | 1.7b |
| 20 | Levy | 2.4k | 24k | 240k | 24k | 240k | 2.4m | 24m | 240m | 2.4b |
| 21 | Goko | 3.5k | 35k | 350k | 35k | 350k | 3.5m | 35m | 350m | 3.5b |
| 22 | Super Saiyen | 5k | 50k | 500k | 50k | 500k | 5m | 50m | 500m | 5b |
| 23 | Todoh | 11k | 110k | 1.1m | 110k | 1.1m | 11m | 110m | 1.1b | 11b |
| 24 | Maheto | 16k | 165k | 1.6m | 165k | 1.6m | 16m | 165m | 1.6b | 16b |
| 25 | Madera | 25k | 250k | 2.5m | 250k | 2.5m | 25m | 250m | 2.5b | 25b |
| 26 | Sakuna | 38k | 380k | 3.8m | 380k | 3.8m | 38m | 380m | 3.8b | 38b |
| 27 | Gujo | 57k | 575k | 5.7m | 575k | 5.7m | 57m | 575m | 5.7b | 57b |
| 28 | Namee | 85k | 850k | 8.5m | 850k | 8.5m | 85m | 850m | 8.5b | 85b |
| 29 | Usop | 125k | 1.2m | 12m | 1.2m | 12m | 125m | 1.2b | 12b | 125b |
| 30 | Enol | 290k | 2.9m | 29m | 2.9m | 29m | 290m | 2.9b | 29b | 290b |
| 31 | Buu | 450k | 4.5m | 45m | 4.5m | 45m | 450m | 4.5b | 45b | 450b |
| 32 | Vegata | 700k | 7m | 70m | 7m | 70m | 700m | 7b | 70b | 700b |
| 33 | Yuju | 1.1m | 11m | 110m | 11m | 110m | 1.1b | 11b | 110b | 1.1t |
| 34 | Jogu | 1.7m | 17m | 175m | 17m | 175m | 1.7b | 17b | 175b | 1.7t |
| 35 | Mahorago | 2.7m | 27m | 275m | 27m | 275m | 2.7b | 27b | 275b | 2.7t |
| 36 | Itacha | 4.5m | 45m | 450m | 45m* | 450m | 4.5b | 45b | 450b | 4.5t |
| 37 | Kaidon | 12m | 125m | 1.2b | 125m | 1.2b | 12b | 125b | 1.2t | 12t |
| 38 | Loffy | 22m | 225m | 2.2b | 225m | 2.2b | 22b | 225b | 2.2t | 22t |
| 39 | Saytama | 40m | 400m | 4b | 400m | 4b | 40b | 400b | 4t | 40t |
| 40 | Bills | 75m | 750m | 7.5b | 750m | 7.5b | 75b | 750b | 7.5t | 75t |
| 41 | Obita | 135m | 1.3b | 13b | 1.3b | 13b | 135b | 1.3t | 13t | 135t |
| 42 | Killer | 240m | 2.4b | 24b | 2.4b | 24b | 240b | 2.4t | 24t | 240t |
| 43 | Gon | 430m | 4.3b | 43b | 4.3b | 43b | 430b | 4.3t | 43t | 430t |
| 44 | Eskanar | 775m | 7.7b | 77b | 7.7b | 77b | 775b | 7.7t | 77t | 775t |
| 45 | Asto | 1.4b | 14b | 140b | 14b | 140b | 1.4t | 14t | 140t | 1.4qd |
| 46 | Jin-woo | 2.5b | 25b | 250b | 25b | 250b | 2.5t | 25t | 250t | 2.5qd |
| 47 | Angel | 4.5b | 45b | 450b | 45b | 450b | 4.5t | 45t | 450t | 4.5qd |
| 48 | Ul Goko | 8b | 80b | 800b | 80b | 800b | 8t | 80t | 800t | 8qd |
| 49 | Arin | 14b | 145b | 1.4t | 145b | 1.4t | 14t | 145t | 1.4qd | 14qd |
| 50 | Ginus | 26b | 260b | 2.6t | 260b | 2.6t | 26t | 260t | 2.6qd | 26qd |
| 51 | Android 17 | 47b | 470b | 4.7t | 470b | 4.7t | 47t | 470t | 4.7qd | 47qd |
| 52 | Mikasu | 85b | 850b | 8.5t | 850b* | 8.5t* | 85t | 850t | 8.5qd | 85qd |
| 53 | Beast Gokan | 150b | 1.5t | 15t | 1.5t | 15t | 150t | 1.5qd | 15qd | 150qd |
| 54 | Denjo | 270b | 2.7t | 27t | 2.7t | 27t | 270t | 2.7qd | 27qd | 270qd |
| 55 | Okarin | 490b | 4.9t | 49t | 4.9t | 49t | 490t | 4.9qd | 49qd | 490qd |
| 56 | Ryek | 880b | 8.8t | 88t | 8.8t | 88t | 880t | 8.8qd | 88qd | 880qd |
| 57 | Dio | 1.6t | 16t | 160t | 16t | 160t | 1.6qd | 16qd | 160qd | 1.6qi |
| 58 | Isago | 2.9t | 29t | 290t | 29t | 290t | 2.9qd | 29qd | 290qd | 2.9qi |
| 59 | Mobb | 5.2t | 52t | 520t | 52t | 520t | 5.2qd | 52qd | 520qd | 5.2qi |
| 60 | Thorfyn | 9.4t | 94t | 940t | 94t | 940t | 9.4qd | 94qd | 940qd | 9.4qi |
| 61 | Kafko | 17t | 170t | 1.7qd | 170t | 1.7qd | 17qd | 170qd | 1.7qi | 17qi |
| 62 | Kiritoe | 31t | 310t | 3.1qd | 310t | 3.1qd | 31qd | 310qd | 3.1qi | 31qi |
| 63 | Gilgamash | 56t | 560t | 5.6qd | 560t | 5.6qd | 56qd | 560qd | 5.6qi | 56qi |
| 64 | Katakury | 100t | 1qd | 10qd | 1qd | 10qd | 100qd | 1qi | 10qi | 100qi |
| 65 | Utah | 180t | 1.8qd | 18qd | 1.8qd | 18qd | 180qd | 1.8qi | 18qi | 180qi |
| 66 | Rimero | 330t | 3.3qd | 33qd | 3.3qd | 33qd | 330qd | 3.3qi | 33qi | 330qi |
| 67 | Mazun | 600t | 6qd | 60qd | 6qd | 60qd | 600qd | 6qi | 60qi | 600qi |
| 68 | Almait | 1.1qd | 11qd | 110qd | 11qd | 110qd | 1.1qi | 11qi | 110qi | 1.1sx |
| 69 | Garuo | 2qd | 20qd | 200qd | 20qd | 200qd | 2qi | 20qi | 200qi | 2sx |
| 70 | Bruly | 3.6qd | 36qd | 360qd | 36qd | 360qd | 3.6qi | 36qi | 360qi | 3.6sx |
| 71 | Suffer | 6.5qd | 65qd | 650qd | 65qd | 650qd | 6.5qi | 65qi | 650qi | 6.5sx |
| 72 | ??? (locked) | 12qd | 120qd | 1.2qi | 120qd | 1.2qi | 12qi | 120qi | 1.2sx | 12sx |
| 73 | Griffin | 22qd | 220qd | 2.2qi | 220qd | 2.2qi | 22qi | 220qi | 2.2sx | 22sx |
| 74 | Bezerk | 40qd | 400qd | 4qi | 400qd | 4qi | 40qi | 400qi | 4sx | 40sx |
| 75 | ??? (locked) | 72qd | 720qd | 7.2qi | 720qd | 7.2qi | 72qi | 720qi | 7.2sx | 72sx |
| 76 | Strike | 130qd | 1.3qi | 13qi | 1.3qi | 13qi | 130qi | 1.3sx | 13sx | 130sx |
| 77 | ??? (locked) | 235qd | 2.3qi | 23qi | 2.3qi | 23qi | 235qi | 2.3sx | 23sx | 235sx |
| 78 | ??? (locked) | 420qd | 4.2qi | 42qi | 4.2qi | 42qi | 420qi | 4.2sx | 42sx | 420sx |
| 79 | ??? (locked) | 760qd | 7.6qi | 76qi | 7.6qi | 76qi | 760qi | 7.6sx | 76sx | 760sx |
| 80 | ??? (locked) | 1.4qi | 14qi | 140qi | 14qi | 140qi | 1.4sx | 14sx | 140sx | 1.4sp |

### 1c. Locked entries per tab (on this account)
Read from the silhouettes. "unclear" = covered by a pop-up in the capture.
- **None:** #72 (12qd), #75 (72qd), #77–#80 (235qd, 420qd, 760qd, 1.4qi). Strike, Bezerk, Griffin, Suffer, Bruly and Garuo are discovered.
- **Huge:** everything from Bruly (#70, 36qd) upward. Garuo (20qd) and below are all discovered.
- **Titanic:** Katakury (10qd), Utah (18qd), Rimero (33qd), Almait (110qd), and everything from Garuo (200qd) upward. Mazun (60qd) is discovered.
- **Silver:** Perfect Zell, Tanjuro, Gujo, Namee, Usop, Buu, Vegata, Yuju, Jogu, Mahorago, Itacha (looked locked), Rimero, Almait, and everything from Garuo upward. Eskanar and Mikasu: unclear.
- **Gold:** Krillan, Inasuke, Pikolo, Hasoka, Zaro, Levy, Goko through Buu (#21–#31), and everything from Utah (18qd) upward. Vegata (70m) and Yuju through Katakury are discovered.
- **Emerald:** Perfect Zell, Bakuga (looked locked), Deko through Gujo (#17–#27), Thorfyn, Kiritoe, Gilgamash (looked locked), Katakury, and everything from Utah upward. Namee: unclear. Usop through Mobb and Kafko are discovered.
- **Diamond:** Inasuke, Tien, Pikolo, Kakeshi, Zenitsa through Super Saiyen (#13–#22), Okarin, Ryek, Dio, Isago, Mobb, and everything from Kafko (170qd) upward. Thorfyn is discovered.
- **Ruby:** Ichiga, Aizan, Krillan through Bakuga (#5–#16), Android 17, and everything from Beast Gokan (#53) upward. Naroto, Ginyou, and Deko through Mikasu (except Android 17) are discovered.
- **Rainbow:** Naroto, Ichiga, Ginyou, Krillan through Friza (#5–#10), Angel, Arin, Android 17, Mikasu, and everything from Beast Gokan (#53) upward (the #53–#56 row looked locked). Aizan, Kakeshi, Perfect Zell through Ul Goko (except Angel), and Ginus are discovered.

### 1d. Rarity tiers (worked out from tooltips and border colours)

| Tier | Border colour | Base odds seen | Boundary (inferred) |
|---|---|---|---|
| Common | grey | 2 – 95 | < 100 |
| Uncommon | green | 130 – 850 (Huge Krillan 110 = Uncommon) | 100 |
| Rare | blue | 1.2k – 85k | 1k |
| Epic | purple | 125k – 4.5m (Ruby Naroto 200k = Epic) | 100k |
| Legendary | gold/orange | 12m – 775m | 10m |
| Mythical | red | 1.4b – 85b | 1b |
| Divine | dark blue/indigo | 150b – 9.4t | 100b |
| Exotic | teal/green | 17t – 600t | 10t |
| Celestial | pink/rainbow gradient | 1.1qd – 40qd (locked 72qd has this border) | 1qd |
| Secret I | bright red | 130qd (Strike); locked 235qd – 1.4qi | 100qd |
| Secret II (name from the white dice tags) | white/silver | only via size/mutation: first seen at 100qi (Rainbow tab) – 14sx | ≈100qi |
| Heavenly (name from the gold dice tag) | gold/yellow | only via mutation: 130sx – 1.4sp (Rainbow/Ruby tabs) | ≈100sx |

Every boundary falls between two observed units, e.g. Kakeshi 95 = Common and Huge Krillan 110 = Uncommon. The exact cut-offs are my inference; the game doesn't state them. The Secret II and Heavenly names come from matching the white and gold border colours to the dice shop's coloured rarity tags; no unit card with those names was visible (all locked).

---

## 2. Mutations

| Order (Index column) | Mutation | "1 in X" multiplier on the unit | Card badge |
|---|---|---|---|
| (top) | ✖ red X | none (same as the default view) | — |
| 1 | Silver | ×10 | silver ingot |
| 2 | Gold | ×100 | gold ingot |
| 3 | Emerald | ×1,000 | green gem |
| 4 | Diamond | ×10,000 | blue diamond |
| 5 | Ruby | ×100,000 | red gem |
| 6 | Rainbow | ×1,000,000 | rainbow gem |
| size | Huge | ×10 | "Huge" name prefix |
| size | Titanic | ×100 | "Titanic" name prefix |

- **Implied chance per roll.** The Index lists a mutated unit at base × multiplier, so a mutation behaves like an extra 1-in-10 / 100 / 1k / 10k / 100k / 1m roll on top of the unit. Huge is 1 in 10 and Titanic is 1 in 100. This is inferred from the Index numbers. I found no separate mutation-odds panel in the Index, the shops, the Upgrades tree or the Backpack.
- **Stacking confirmed:** the world label "Emerald Huge Eskanar 1 in 7.7t" (775m × 10 × 1,000). The roll banners also decompose cleanly (section 4).
- **Mutated unit card** (Index tooltip, Ruby tab): the name shows without a prefix ("Naroto"). Then **Epic**, Level 1, **$6.9k/s**, 1 in 200k. Ruby Ginyou: Epic, $11k/s, 1 in 400k. Base Naroto is Common at $1/s.
- **Huge unit cards:** Huge Naroto Common $8/s 1 in 20 · Huge Ginyou Common $14/s 1 in 40 · Huge Krillan Uncommon $30/s 1 in 110 · Huge Perfect Zell Rare 1 in 1.3k ($180/s, edge cut off).
- **Placed units in the world** show a floating label: mutation name (coloured) / size + name / rarity (coloured) / 1 in X / $ per second. Examples: "Huge Thorfyn / Exotic / 1 in 94t / $3.4t/s"; "Emerald / Huge Eskanar / Divine / 1 in 7.7t / $870b/s". These income numbers are far above the Index base values, so placed-unit income likely includes extra boosts. I didn't check which.
- **Titanic unit cards:** Titanic Kaidon: Mythical, Level 1, $3.9m/s, 1 in 1.2b (base Kaidon: Legendary, $139k/s). Titanic Obita: Mythical, $22m/s, 1 in 13b (base: $784k/s). Income is ×28 the base unit.
- **Combined filters work:** Huge + Silver = ×100 (see section 1).

---

## 3. Dice shop
Reached with the green **Shop** button in the top bar (it teleports you to the shop area: Market / Dice Shop / Sell Units), then walking into the Dice Shop stall. The list scrolls. Every die on this account is already owned: the buttons say **Equip**, and Radiant says **Equipped**. So **no prices are shown anywhere**. I didn't equip or buy anything. Screenshots 25 (all 29 dice) and 26.

| # | Die | Rarity tag | Luck | × previous die |
|---|---|---|---|---|
| 1 | Normal | Common | 2x | — |
| 2 | Fire | Uncommon | 5x | 2.5 |
| 3 | Water | Uncommon | 10x | 2 |
| 4 | Nature | Rare | 20x | 2 |
| 5 | Lightning | Rare | 42x | 2.1 |
| 6 | Ice | Rare | 100x | 2.38 |
| 7 | Magma | Epic | 200x | 2 |
| 8 | Storm | Epic | 400x | 2 |
| 9 | Shadow | Epic | 750x | 1.88 |
| 10 | Light | Legendary | 1,500x | 2 |
| 11 | Blood Moon | Legendary | 3,000x | 2 |
| 12 | Void | Legendary | 6,000x | 2 |
| 13 | Solar | Mythical | 12,500x | 2.08 |
| 14 | Lunar | Mythical | 25,000x | 2 |
| 15 | Galaxy | Mythical | 50,000x | 2 |
| 16 | Black Hole | Divine | 100,000x | 2 |
| 17 | Dragon | Divine | 200,000x | 2 |
| 18 | Royal | Exotic | 400,000x | 2 |
| 19 | Prismatic | Exotic | 1,000,000x | 2.5 |
| 20 | Arcane | Celestial | 2,000,000x | 2 |
| 21 | Corrupted | Celestial | 5,000,000x | 2.5 |
| 22 | Titan | Celestial | 10,000,000x | 2 |
| 23 | Chrono | Secret I | 25,000,000x | 2.5 |
| 24 | Cyber | Secret I | 62,500,000x | 2.5 |
| 25 | Toxic | Secret I | 150,000,000x | 2.4 |
| 26 | Ethereal | Secret II | 375,000,000x | 2.5 |
| 27 | Frostfire | Secret II | 950,000,000x | 2.53 |
| 28 | Alchemy | Secret II | 2,000,000,000x | 2.1 |
| 29 | Radiant | Heavenly | 5,000,000,000x | 2.5 (**equipped**) |

Dice per tag: Common 1, Uncommon 2, Rare 3, Epic 3, Legendary 3, Mythical 3, Divine 2, Exotic 2, Celestial 3, Secret I 3, Secret II 3, Heavenly 1. The tag colours match the Index border colours.

Robux products advertised on the right of the HUD. I only saw the buttons and did not open or buy any (price in Robux):
Luck 79 · Ultra Luck 199 · More Cash 79 · VIP 99 · Roll Speed 139 · Double Roll 319 · Jackpot Roll ("999x luck") 35.

---

## 4. How a rare / mutated pull is shown
- **Manual roll (Auto off):** pressing ROLL hides the HUD and darkens the screen with a coloured vignette. The unit model appears in the centre inside a glowing crystal frame with white streaks on both sides. **"1 in X" sits above it in the tier colour** and the **name** sits below in large white text with the size prefix. Colours I saw: green/teal for Exotic-range results (1 in 24t, 94t, 22.5t), red for 1 in 220qd (Secret I range), rainbow for 1 in 88qd (Celestial range). Each result shows for roughly 0.25–0.5 s. One press sometimes showed two results back to back (Titanic Ginus 1 in 26t, then Loffy 1 in 22.5t), which suggests a multi-roll; I didn't check where it comes from. Screenshots 27, 28.
- **Auto:** during a roll the ROLL button turns into an **AUTO** toggle. With Auto on, a **HIDE** button appears next to it (screenshot 29). HIDE shrinks the reveal to the small top-centre banner and brings the HUD back while auto-rolling continues. That was the state when I first joined. When I came back for the second session Auto was off. I turned it on to test it and **turned it back off** before leaving.
- **Small banner (Auto + HIDE):** unit portrait in a glowing hexagonal frame, "1 in X" above, name with size prefix below (screenshots 04/05). **The mutation is not named** in the banner or the big reveal; the "1 in X" already includes it.
- **Pop-ups on the right while playing:** "+1 Luck I", "+2 Luck III", "+1 Damage I/II/III", "+1 Income I/II/III", "+2 Trait Reroll", "+5 / +10 Gems". These are the potions/items in section 5. Centre messages seen: "Grade Event has started!", "Cash Event has started!".
- **Caution about breaking the banners down.** One manual roll showed **"Griffin — 1 in 220qd"** (×10 Griffin's 22qd). Afterwards the normal Griffin entry was discovered (Celestial, $705b/s, 1 in 22qd), but the Huge and Silver 220qd Griffin entries were still locked. So that ×10 wasn't Huge or Silver, and the banner may include another factor, such as grade or trait. Treat the size × mutation breakdown below as likely, not confirmed.

Banners seen with Auto on. The breakdown is my arithmetic from the Index values:

| Banner | Base odds | Breakdown |
|---|---|---|
| Kiritoe 1 in 310t | 31t | ×10 → Silver |
| Thorfyn 1 in 94t | 9.4t | ×10 → Silver |
| Thorfyn 1 in 940t | 9.4t | ×100 → Gold |
| Jin-woo 1 in 25t | 2.5b | ×10,000 → Diamond |
| Angel 1 in 45t | 4.5b | ×10,000 → Diamond |
| Killer 1 in 24t | 240m | ×100,000 → Ruby |
| Okarin 1 in 49t | 490b | ×100 → Gold |
| Loffy 1 in 22.5t | 22.5m | ×1,000,000 → Rainbow |
| Huge Mobb 1 in 52t | 5.2t | Huge ×10 only |
| Huge Kafko 1 in 170t | 17t | Huge ×10 only |
| Huge Isago 1 in 29t | 2.9t | Huge ×10 only |
| Huge Thorfyn 1 in 94t | 9.4t | Huge ×10 only |
| Huge Ul Goko 1 in 80t | 8b | Huge ×10 × Emerald ×1,000 |
| Huge Jin-woo 1 in 25t | 2.5b | Huge × Emerald |
| Huge Android 17 1 in 470t | 47b | Huge × Emerald |
| Huge Gon 1 in 4.3t | 430m | Huge × Emerald |
| Huge Killer 1 in 24t | 240m | Huge × Diamond |
| Huge Ryek 1 in 88qd | 880b | Huge × Diamond |
| Huge Saytama 1 in 40t | 40m | Huge × Ruby |
| Huge Mahorago 1 in 27.5t | 2.75m | Huge × Rainbow |
| Titanic Okarin 1 in 49t | 490b | Titanic ×100 only |
| Titanic Ginus 1 in 26t | 26b | Titanic × Silver |
| Titanic Mikasu 1 in 85t | 85b | Titanic × Silver |
| Titanic Killer 1 in 24t | 240m | Titanic × Emerald |
| Titanic Saytama 1 in 40t | 40m | Titanic × Diamond |
| Titanic Enol 1 in 29t | 290k | Titanic × Rainbow |
| Titanic Buu 1 in 45t | 450k | Titanic × Rainbow |
| Titanic Vegata 1 in 70t | 700k | Titanic × Rainbow |

At x19.7t luck most results landed at 1 in 4.3t–940t, i.e. roughly 0.2–50× the luck value. The outliers were 1 in 88qd and 1 in 220qd.

---

## 5. Luck and boosts

### Current luck: x19.7t (clover icon, bottom-right; no tooltip on hover)
It decomposes exactly as **equipped die × Rebirth × (1 + Luck upgrades + Fortune upgrades)**:
5,000,000,000 (Radiant) × 40 (Rebirth, MAX) × (1 + 43.5 + 54) = 5,000,000,000 × 40 × 98.5 = **19,700,000,000,000 = 19.7t**.
This assumes every upgrade node below is bought. Their tooltips show only the bonus, with no price. No luck potion was active. The clover stayed at x19.7t all session while potions sat unused in the backpack.

### Upgrades tree (UPGRADES button; hex skill tree, drag to pan)
| Branch | Nodes and bonus (from tooltips) | Total |
|---|---|---|
| Luck (green clover) | I +0.5x · II +1x · III +1x · IV +2x · V +2x · VI +3x · VII +3x · VIII +3x · IX +4x · X +4x · XI +4x · XII +5x · XIII +5x · XIV +6x | +43.5x |
| Fortune (purple clover, same luck icon in tooltip) | I +2x · II +2x · III +3x · IV +3x · V +3x · VI +4x · VII +5x · VIII +5x · IX +6x · X +6x · XI +7x · XII +8x | +54x |
| Grade Luck (purple gem) | I +0.05x · II +0.08x · III +0.1x · IV +0.12x · V +0.15x · VI +0.2x · VII +0.25x · VIII +0.3x | +1.25x |
| Trait Luck (crystal) | I +0.05x · II +0.08x · III +0.1x · IV +0.12x · V +0.15x · VI +0.2x · VII +0.25x · VIII +0.3x | +1.25x |
| Roll Speed | I −0.15 (others not read) | — |
| Other branches (not read) | Money I–XII, Sell I–IX, Unit Storage, Walkspeed, Damage, Health I–VIII | — |

XIV, XII and VIII are the highest nodes I could find in each branch; the tree view would not pan further. Grade Luck and Trait Luck feed the separate Grade/Trait systems, not the clover number.

### Rebirth (left REBIRTH button)
"40x Luck → MAX", "40x Cash → MAX", bar at MAX, warning "Rebirthing resets your cash!". I didn't rebirth.

### Potions / items (BACKPACK → Items, from hover tooltips; I didn't use any)
| Item | Rarity | Effect | Duration |
|---|---|---|---|
| Luck I | Rare | x1.25 luck | 5m 0s |
| Luck II | Epic | x1.5 luck | 5m 0s |
| Luck III | Legendary | x2 luck | 5m 0s |
| Luck IV | Mythical | x4.25 luck | 5m 0s |
| Leaf Luck I / II / III | Rare / Epic / Legendary | x2 / x3 / x4 luck | 3m 30s |
| Slayer Luck I / II / III | Rare / Epic / Legendary | x2 / x3 / x4 luck | 3m 30s |
| Pirate Luck I / II / III | Rare / Epic / Legendary | x1.5 / x2 / x3 luck | 4m 0s |
| Cursed Luck I / II / III | Rare / Epic / Legendary | x1.25 / x1.5 / x2 luck | 3m 0s |
| Dragon Luck I / II / III | Rare / Epic / Legendary | x1.25 / x1.5 / x2 luck | 2m 0s |
| Income I / II / III / IV | Rare / Epic / Legendary / Mythical | x1.25 / x1.5 / x2 / x4 income | 5m 0s |
| Slayer Income I / II | Rare / Epic | x1.5 / x2 income | 3m 30s |
| Dragon Income II | Epic | x1.75 income | 2m 0s |
| Damage I / II / III / IV | Rare / Epic / Legendary / Mythical | x1.5 / x2 / x3 / x5 damage | 5m 0s |
| Slayer Damage I / II | Rare / Epic | x2 / x3 damage | 3m 30s |
| Gems, Trait Reroll, Tickets | Celestial (currency items) | — | — |

The plain Luck/Income/Damage potions last 5 minutes. The themed ones are stronger but shorter. Their names match the Towers (Dragon, Cursed, Pirate…), so the towers probably drop them; that's my inference.

### Other HUD notes
- **Friend Boost** (bottom-left): +0%, later +10%. Money: $503.04oc.
- **Daily Rewards** (closed without claiming): Day 1 green potion ×2, Day 2 outfit ×1, Day 3 crystal ×16, Day 4 green clover ×3, Day 5 purple gem ×32, Day 6 blue clover ×2, Day 7 character ×1.
- Boost timers seen in the first session (before I could read tooltips): gold pouch 59s, red horned potion 53s, yellow potion 2m 3s, red potion 3m 22s, a ~25-minute orb timer, a purple gem timer ~4–5 min. Later a green cash-stack timer appeared during the "Cash Event".
- A "Floor N" counter over the character keeps rising and resetting (tower progress).

---

## 6. Other systems seen (not fully captured)
- **Hub** (top HUB button): **Towers** (walk in → list: Dragon Tower *Easy*, Cursed Tower *Medium*, Pirate Tower…, each with Play), **Grades**, **Traits**, **Trade**, **Quests** and **Fusing** stations. Walking into Trade opens a "Trading!" list of players with Send buttons; I closed it without sending anything.
- **Grades / Traits** stations: see section 7. I couldn't open them myself (walking up and pressing E did nothing); the numbers come from your screenshots of the two menus.
- **Backpack:** tabs Units / Items / Gears. The Units tab showed storage 12/170 with an empty grid, plus an "Equip Best" button (not clicked).

---

## 7. Grades and Traits (from your screenshots, 14:41)
Both menus open from the hub stations. Each has a unit slot (+), Roll / Auto Roll buttons and a settings cog, with the odds listed down the right side as **percentages**. Your Grade Luck and Trait Luck upgrades (+1.25x each, section 5) may already be applied to these numbers; the menus don't say. Screenshots 41–45.

### Grades: 1 Gem per roll (you have 28k); income multiplier only
| Grade | Chance | ≈ 1 in X | Income |
|---|---|---|---|
| ∞ (infinity sign) | 0.001% | 100,000 | ×100 |
| 神 (kanji "god") | 0.0039% | 25,641 | ×50 |
| Z+ | 0.014% | 7,143 | ×25 |
| Z | 0.048% | 2,083 | ×15 |
| S+ | 0.16% | 625 | ×10 |
| S | 1.1% | 91 | ×7 |
| A+ | 3.4% | 29 | ×4.5 |
| A | 8.6% | 11.6 | ×3 |
| B | 15.5% | 6.5 | ×1.7 |
| C | 27.7% | 3.6 | ×1.2 |
| D | 43.1% | 2.3 | ×1.1 |

The listed chances add up to 99.63%; the gap is presumably display rounding. These are the in-game numbers. The third-party guide I quoted earlier was incomplete: it missed the ∞ and 神 grades and gave B as ×1.6.

### Traits: 1 Trait Reroll per roll (you have 924)
The menu warns: "Rerolling a trait will replace any current traits!" Its trait box showed "Damage II" (greyed).

| Trait | Chance | ≈ 1 in X | Effect |
|---|---|---|---|
| Paradox | 0.0022% | 45,455 | ×57.5 income, damage and health |
| Eternal | 0.0051% | 19,608 | ×30 income, damage and health |
| Transcendent | 0.011% | 9,091 | ×15 income, damage and health |
| Monarch | 0.042% | 2,381 | ×8 income, damage and health |
| Shogun | 0.18% | 556 | ×5 income, damage and health |
| Samurai | 0.67% | 149 | ×3 income, damage and health |
| Money III / Damage III / Health III | 1.5% each | 67 | ×2 to that stat |
| Money II / Damage II / Health II | 6.8% each | 14.7 | ×1.5 to that stat |
| Money I / Damage I / Health I | 24.5% each | 4.1 | ×1.2 to that stat |

That's 15 traits in total: 9 single-stat traits (3 families × 3 levels) and 6 all-stat traits. The listed chances add up to 99.31%; the gap is presumably display rounding.

**How the three layers fit together:** a unit's "1 in X" comes from base × size × mutation and is driven by your luck (die × rebirth × upgrades). Grade and trait are rolled separately afterwards, from fixed % tables with their own small luck bonuses. Grades only boost income; traits boost income, damage and health.

---

## Still to collect next session
1. Dice **prices**. They aren't displayed because every die is owned; you'd need a fresh/alt account to see them.
2. The Market / Sell Units / Gears contents.
3. What the extra ×10 on the "Griffin 1 in 220qd" banner was (section 4).

## Screenshots (`AnimeDice-screenshots/`)

- `01-main-hud-luck-potions.jpg`
- `02-hud-luck-x19.7t-and-potion-timers.jpg`
- `03-world-labels-mutated-huge-units.jpg`
- `04-roll-result-banner-titanic-buu-1in45t.jpg`
- `05-roll-result-banner-huge-killer-1in24t.jpg`
- `06-index-normal-top-with-tabs.jpg`
- `07-index-unit-tooltip-naroto.jpg`
- `08-index-normal-end-locked-secrets.jpg`
- `09-index-huge-top.jpg`
- `10-index-huge-end-locked.jpg`
- `11-index-titanic-locked-rows.jpg`
- `12-index-silver-tab.jpg`
- `13-index-gold-tab.jpg`
- `14-index-emerald-tab.jpg`
- `15-index-emerald-end-1.4sx.jpg`
- `16-index-diamond-tab.jpg`
- `17-index-diamond-end-14sx.jpg`
- `18-index-ruby-tab.jpg`
- `19-index-ruby-end-140sx.jpg`
- `20-index-rainbow-tab.jpg`
- `21-index-rainbow-end-1.4sp-gold-borders.jpg`
- `22-index-mutation-column-with-rainbow.jpg`
- `23-ruby-naroto-card.jpg`
- `24-daily-rewards.jpg`
- `25-dice-shop-all-29-dice.jpg`
- `26-dice-shop-end-radiant-equipped.jpg`
- `27-manual-roll-reveal-titanic-killer.jpg`
- `28-manual-roll-reveal-griffin-1in220qd.jpg`
- `29-auto-roll-overlay-auto-hide-buttons.jpg`
- `30-upgrades-tree-center.jpg`
- `31-upgrades-tree-luck-fortune-grade-trait.jpg`
- `32-rebirth-40x-luck-max.jpg`
- `33-backpack-items-top.jpg`
- `34-backpack-items-bottom.jpg`
- `35-potion-tooltip-luck-iv.jpg`
- `36-titanic-kaidon-card.jpg`
- `37-griffin-card-celestial.jpg`
- `38-index-huge-plus-silver-combined.jpg`
- `39-hub-towers-grades-traits.jpg`
- `40-upgrade-tooltip-luck-i.jpg`
- `41-traits-odds-1-paradox-to-shogun.png`
- `42-traits-odds-2-samurai-to-damage-iii.png`
- `43-traits-odds-3-damage-ii-to-money-i.png`
- `44-grades-odds-1-infinity-to-a-plus.png`
- `45-grades-odds-2-s-to-d.png`
