# Steal a Floatie 🎈 — starter game

## Play it in 2 minutes
1. Install **Roblox Studio** (free) and log in.
2. Double-click **StealAFloatie.rbxlx** (or open it with File > Open from File in Studio).
3. Press **Play**. The map, bases, Pump Line and HUD all build themselves when the game starts.
4. To test stealing, open the **Test** tab, set **Clients** to 2 and click **Start**. That opens two players.

## Test commands (type in chat while testing in Studio)
| Command | What it does |
|---|---|
| `;air 1000000` | gives you Air |
| `;give Dragonflate Rainbow` | spawns a Floatie (optional 3rd value = stage 1–5) |
| `;grow` | inflates all your Floaties by 1 stage |
| `;event GoldenHour` | starts an event (HeliumRain, GoldenHour, WindyDay, Thunderstorm, SecretSkies) |

## Before you publish
- File > **Publish to Roblox**. Then go to Game Settings > Security and turn on **Enable Studio Access to API Services** so you can test saving.
- Game Settings > Places > set **Max Players = 8** (there are 8 bases).
- Create the game passes and developer products on create.roblox.com and paste their IDs into `Config` (ReplicatedStorage > Shared > Config).
- Put your Roblox UserId in `Config.AdminUserIds`.

## Where things are
| Script | Job |
|---|---|
| `ReplicatedStorage/Shared/Config` | **Edit this one for updates**: Floaties, prices, stages, events, codes, Robux products |
| `ReplicatedStorage/Shared/FloatieModel` | builds the balloon-animal models from shapes (no 3D modeling) |
| `ServerScriptService/GameServer` | all the gameplay: buying, income, inflating, stealing, darts, lock, rebirth, events, purchases, saving |
| `ServerScriptService/Server/DataService` | saving and loading |
| `ServerScriptService/Server/MapBuilder` | builds the map and the Dart Blaster |
| `StarterPlayer/StarterPlayerScripts/ClientMain` | HUD, shop, notifications, dart shooting |

If you use Rojo, the `src/` folder and `default.project.json` sync the same scripts.
