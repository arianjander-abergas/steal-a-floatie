# Steal a Floatie 🎈

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
| File | In Studio | Job |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage/Shared/Config` | **Edit this one for updates**: Floaties, prices, stages, events, codes, Robux products |
| `src/shared/FloatieModel.luau` | `ReplicatedStorage/Shared/FloatieModel` | builds the balloon-animal models from shapes (no 3D modeling) |
| `src/GameServer.server.luau` | `ServerScriptService/GameServer` | all the gameplay: buying, income, inflating, stealing, darts, lock, rebirth, events, purchases, saving |
| `src/server/DataService.luau` | `ServerScriptService/Server/DataService` | saving and loading |
| `src/server/MapBuilder.luau` | `ServerScriptService/Server/MapBuilder` | builds the map and the Dart Blaster |
| `src/client/ClientMain/` | `StarterPlayer/StarterPlayerScripts/ClientMain` | LocalScript `ClientMain` (`init.client.luau`) plus modules: Kit = UI toolkit, HUD, Shop/Rebirth/Codes panels, and gameplay helpers (toasts, sounds, event banner, carry box, tutorial, prompts, darts, knockback, effects) |

`Art/` holds the game icon and thumbnail for the Roblox page.

## Editing with Rojo
1. In PowerShell: `cd "C:\Users\AIAN\Desktop\Roblox Games"` then `rojo serve`.
2. In Studio, open `StealAFloatie.rbxlx`, then Plugins > Rojo > Connect.
3. Edit scripts in VS Code (not Studio's script editor). Saves appear in Studio instantly.
4. When something works, commit and push with GitHub Desktop.
