# Restaurant Tycoon (Godot 4.5 starter)

## Run it
1. Open Godot 4.5 -> Import -> select `project.godot`.
2. Press F5. It runs immediately with colored-box placeholders.

## How it plays (first person)
Controls: WASD move, mouse look, E or left click interact, B (or Esc) opens the shop, V build mode, P pause / settings.

1. A customer walks in and sits. A chat bubble above them shows what they want.
2. Look at them and press E to take the order (or hire a waiter to do it). A paper ticket appears on the board on the back wall.
3. Click a ticket. The food goes onto a free **stove burner** or **counter prep spot** (depending on the dish), sitting in a pan, pot, board or plate.
4. Walk to that spot and press E. The minigame for that dish pops up (see below). Esc cancels; the food stays put so you can try again.
5. The finished dish goes on the ORDER UP table. Press E on a plate to carry it yourself, or let a waiter deliver it.
6. Serve the right customer with E. They eat, pay (more for a better dish, plus a tip for being quick) and leave.

The starter kitchen has a stove (4 burners) and a prep counter (2 spots). Buy more of either in build mode.
Hired cooks take tickets and cook automatically on any free matching spot (a bit slower than a perfect run, never burnt). Waiters take orders and deliver plates.
If a customer runs out of patience they leave angry; their ticket / food / plate disappears.
Progress saves every 15 seconds and on close; offline earnings are paid on load (capped at 8 hours, more with staff).

## The shop (press B)
A window with a scrolling grid of cards. Each card has a 3D preview, what it does, and a button. Mouse wheel scrolls.

| Tab | What's in it |
|---|---|
| Dishes | All 40 dishes. Shows the price per plate, the station (Stove / Counter) and the minigame. Unlock new ones. |
| Upgrades | Easier cooking (bigger zones, slower markers, faster chefs, 10 levels), Marketing (customers arrive 10% faster per level, 5 levels), Comfy seating (customers wait 15% longer per level, 5 levels) |
| Staff | Hire cooks (up to 4) and waiters (up to 3) |
| Build | Every table, station and decor item. Pressing a Build card closes the shop and starts build mode already holding that item. |
| Restaurant | Your rank and XP, plus the expansions you can buy |

## Dishes, stations and minigames
Each dish is made at the **stove** (needs a free burner) or the **counter** (needs a free prep spot), and uses one of four minigames.
Quality (Perfect / Good / Burnt) changes what the customer pays.

| Minigame | How it works |
|---|---|
| Grill (timing) | Stop the moving marker inside the green zone, once per round. Space / E / Click |
| Fry / pour (hold) | Hold to raise the marker, release to lower it; keep it in the drifting green zone until time runs out |
| Stir / scoop (mash) | Mash Space / E / Click to fill the meter before time runs out; finishing sooner is better |
| Assemble (sequence) | Press the arrows shown, in order, with the arrow keys or W A S D (up / left / down / right); wrong directions cost quality |

| Dish | Station | Minigame | Sells for | Unlock |
|---|---|---|---|---|
| Burger | Stove | Grill | $10 | free |
| Fried Egg | Stove | Grill | $9 | $40 |
| Sandwich | Counter | Assemble | $11 | $50 |
| Soda | Counter | Fry / pour | $6 | $60 |
| Hot Dog | Stove | Grill | $12 | $80 |
| Salad | Counter | Assemble | $12 | $90 |
| Tea | Counter | Fry / pour | $7 | $110 |
| Cheeseburger | Stove | Grill | $13 | $120 |
| Coffee | Counter | Fry / pour | $8 | $130 |
| Bacon | Stove | Grill | $12 | $140 |
| Donut | Counter | Fry / pour | $9 | $150 |
| Corn Dog | Stove | Fry / pour | $13 | $160 |
| Fries | Stove | Fry / pour | $14 | $200 |
| Cupcake | Counter | Assemble | $10 | $200 |
| Ice Cream | Counter | Stir / scoop | $14 | $220 |
| Broth | Stove | Stir / scoop | $16 | $250 |
| Sub | Counter | Assemble | $15 | $280 |
| Sausage | Stove | Grill | $15 | $300 |
| Pancakes | Stove | Grill | $16 | $350 |
| Taco | Counter | Assemble | $17 | $380 |
| Soup | Stove | Stir / scoop | $18 | $400 |
| Double Burger | Stove | Grill | $18 | $450 |
| Waffle | Stove | Grill | $18 | $450 |
| Pizza | Counter | Assemble | $25 | $700 |
| Sundae | Counter | Stir / scoop | $22 | $800 |
| Frappe | Counter | Fry / pour | $20 | $900 |
| Double Cheese | Stove | Grill | $24 | $900 |
| Dim Sum | Stove | Fry / pour | $26 | $1000 |
| Pasta | Stove | Stir / scoop | $28 | $1100 |
| Grilled Fish | Stove | Grill | $30 | $1300 |
| Egg Sushi | Counter | Assemble | $32 | $1500 |
| Cake | Counter | Assemble | $30 | $1600 |
| Cocktail | Counter | Fry / pour | $28 | $1700 |
| Steak | Stove | Grill | $38 | $1800 |
| Maki Roll | Counter | Assemble | $36 | $2000 |
| Pie | Counter | Fry / pour | $34 | $2200 |
| Ribs | Stove | Grill | $44 | $2400 |
| Tajine | Stove | Stir / scoop | $48 | $3000 |
| Sushi | Counter | Assemble | $50 | $3000 |
| Roast Turkey | Stove | Grill | $60 | $4500 |

Every dish is one entry in `autoload/game_state.gd` (`DISHES`): price, cook time, unlock cost, model files, cookware,
difficulty, minigame and station. Add a line there and it appears in the shop automatically.

## Editing in the Godot editor (scenes)
Everything is now a scene you can open and change in the editor (double-click in the FileSystem panel):

| Scene | What it is |
|---|---|
| `scenes/main.tscn` | The restaurant: floor, walls, light, the 8 tables (move them, set each table's **Number**), door, player start |
| `scenes/kitchen.tscn` | Ticket board, stove, order-up table, and the marker spots where tickets, cooks and waiters appear |
| `scenes/stove.tscn` | The stove model and its 4 burners |
| `scenes/counter.tscn` | A prep counter with 2 prep spots (a starter one is added to the kitchen automatically) |
| `scenes/shop_ui.tscn` | The scrolling card-grid shop |
| `scenes/burner.tscn` | One cooking spot (stove burner or counter prep spot): disc, status label, and the Pan / Pot / Board / Plate cookware models. Its **Station** setting decides which dishes use it. |
| `scenes/pass_table.tscn` | The ORDER UP counter and the plate slots on it |
| `scenes/table.tscn` | A table + chair (TableModel, ChairModel), seat / waiter / food points |
| `scenes/customer.tscn` | Customer: model, collision, chat bubble |
| `scenes/cook.tscn`, `scenes/waiter.tscn` | Hired staff |
| `scenes/ticket.tscn`, `scenes/plate.tscn`, `scenes/food.tscn` | Paper ticket, finished plate, and the food model used everywhere |
| `scenes/player.tscn` | First-person player (speed, reach, sensitivity are in the Inspector) |
| `scenes/hud.tscn` | On-screen text, crosshair and shop panel |
| `scenes/cook_minigame.tscn` | Timing (grill) minigame |
| `scenes/minigame_hold.tscn`, `scenes/minigame_mash.tscn`, `scenes/minigame_sequence.tscn` | The other three minigames |
| `scenes/game_sounds.tscn` | **All sounds and the music** (see Sounds below) |
| `scenes/placed_item.tscn`, `scenes/build_ui.tscn`, `scenes/build_sounds.tscn` | Build mode: a piece of decor, the build menu, build sounds |

**Swapping models:** every model sits in a **ModelSlot** node. Select it and in the Inspector drag a `.glb`
onto **Model Path** (or a scene onto **Model Scene**). Change **Fit Size** to make it bigger or smaller (models
are auto-scaled to fit that box and placed on the floor). The model shows up live in the editor.
Customers, cooks and waiters use **Random Paths** (a list of character models; one is picked at random).

**Which food model each dish uses** is set in `autoload/game_state.gd` (the `DISHES` table). How food looks
(size, fallback color) is in `scenes/food.tscn`.

## Sounds
Open `scenes/game_sounds.tscn`. Every node there is an AudioStreamPlayer with no sound yet. Select a node and drag a
.wav or .ogg file onto its **Stream** slot in the Inspector. Nodes with no stream stay silent.

| Node | Plays when |
|---|---|
| Music | Background music (starts automatically and loops) |
| CustomerArrive / OrderTaken / Serve / Eat / Pay / Angry | A customer arrives / you or a waiter take their order / food is served / they eat / they pay / they leave angry |
| NewTicket | A ticket appears on the board |
| PutOnStove | Food is put on a burner |
| Sizzle | Loops while anything is cooking (it restarts itself if the clip is short) |
| OrderUpBell | A plate lands on the ORDER UP table |
| PickUp / Footstep / Interact | You pick up a plate / each step you take (spacing: Player's "Step Interval") / you press E |
| Buy / ShopOpen / ShopClose | Shop purchase / shop opens / closes |
| MinigamePress / Perfect / Good / Miss / Done / Cancel | Minigame button press and results |

## Restaurant rank
Serving customers earns **XP** (more for pricier dishes and better quality), and XP raises your restaurant's **rank**
(1 to 20, shown in the bottom-left corner with a progress bar). When you rank up you get a message listing what just unlocked.

Rank locks almost everything you can buy: **dishes, build items (including table sizes, stoves and counters), upgrade levels,
staff and expansions**. Locked cards in the shop are greyed out and say "Rank N needed"; locked items in the build menu are
dimmed with their rank. Dishes you already own are never taken away.

| Rank | Title | Unlocks |
|---|---|---|
| 1 (0 XP) | Street Stall | Burger, Fried Egg, Sandwich, Soda, Hot Dog, Table for 2, Small Plant, Bar Stool, Trash Can, Easier cooking Lv 1 |
| 2 (100 XP) | Street Stall | Salad, Tea, Cheeseburger, Coffee, Bacon, Donut, Prep Counter (2 spots), Potted Plant, Round Rug, Expansion: East wing, Easier cooking Lv 2, Marketing Lv 1, Waiter #1 |
| 3 (300 XP) | Snack Bar | Corn Dog, Fries, Cupcake, Ice Cream, Broth, Sub, Sausage, Table for 4, Stove (4 burners), Floor Lamp, Coat Rack, Easier cooking Lv 3, Comfy seating Lv 1, Cook #1 |
| 4 (600 XP) | Snack Bar | Pancakes, Taco, Soup, Double Burger, Waffle, Rug, Bench, Expansion: West wing, Easier cooking Lv 4, Marketing Lv 2 |
| 5 (1,000 XP) | Cafe | Pizza, Sundae, Bookcase, Armchair, Easier cooking Lv 5, Comfy seating Lv 2, Waiter #2 |
| 6 (1,500 XP) | Cafe | Frappe, Double Cheese, Table for 6, Coffee Table, Expansion: South hall, Easier cooking Lv 6, Marketing Lv 3, Cook #2 |
| 7 (2,100 XP) | Diner | Dim Sum, Pasta, Sofa, Easier cooking Lv 7, Comfy seating Lv 3 |
| 8 (2,800 XP) | Diner | Grilled Fish, Television, Expansion: South-east hall, Easier cooking Lv 8, Marketing Lv 4, Waiter #3 |
| 9 (3,600 XP) | Bistro | Egg Sushi, Cake, Easier cooking Lv 9, Comfy seating Lv 4, Cook #3 |
| 10 (4,500 XP) | Bistro | Cocktail, Steak, Expansion: South-west hall, Easier cooking Lv 10, Marketing Lv 5 |
| 11 (5,500 XP) | Restaurant | Maki Roll, Comfy seating Lv 5 |
| 12 (6,600 XP) | Restaurant | Pie, Ribs, Expansion: Far south hall, Cook #4 |
| 13 (7,800 XP) | Brasserie | Tajine |
| 14 (9,100 XP) | Brasserie | Sushi, Expansion: Far south-east hall |
| 15 (10,500 XP) | Fine Dining | - |
| 16 (12,000 XP) | Fine Dining | Roast Turkey, Expansion: Far south-west hall |
| 17 (13,600 XP) | Gourmet | - |
| 18 (15,300 XP) | Gourmet | - |
| 19 (17,100 XP) | Five Star | - |
| 20 (19,000 XP) | Five Star | - |

The rank for every item is stored with it: `"rank"` on each dish in `autoload/game_state.gd`, `"rank"` on each build item in
`scripts/build_catalog.gd`, and the upgrade / staff / expansion ranks as small functions and lists in `game_state.gd`.

## Expanding the restaurant
The shop's **Restaurant** tab shows your rank and the expansions. Each one adds another floor **the same size as the starting
room**, attached to what you already have, with walls around the outside. The wall between the rooms is removed so they join up.
Expansions are bought in order: East wing, West wing, South hall, South-east hall, South-west hall and three more further south
(never north: that's the kitchen wall). Each one also raises your **table limit by 3** (4 at the start, up to 28).

| Expansion | Cost | Rank |
|---|---|---|
| East wing | $500 | 2 |
| West wing | $1,200 | 4 |
| South hall | $2,500 | 6 |
| South-east hall | $4,500 | 8 |
| South-west hall | $7,500 | 10 |
| Far south hall | $12,000 | 12 |
| Far south-east hall | $18,000 | 14 |
| Far south-west hall | $26,000 | 16 |

You can build anywhere on the new floors in build mode. The kitchen, ticket board and order-up table stay where they are.
The expansion order and plot size are in `scripts/restaurant_plots.gd`.

## Recipe steps
Most dishes now take **several steps**, each with its own station, minigame and cookware. A burger is *Grill patty* (stove, timing) then
*Build burger* (counter, assembly); a pizza is *Knead dough* (counter), *Add toppings* (counter) and *Bake pizza* (stove). Simple
dishes (fried egg, soda, tea, ice cream, sub) stay one step.

- After each step the order goes **back on the ticket board** as a new ticket ("Step 2/3"). Click it to put the next step on the right
  station, walk there, press E. What's on the pan / board shows the ingredient for that step (a patty, bread, rice...).
- The dish's final quality is the **average of its steps**, so one bad step drags it down.
- More steps pay more: **+20% per extra step**. Customers waiting for longer dishes are a bit more patient.
- Hired cooks do the steps too, spreading the dish's cook time over them.
- Steps live in each dish's `"steps"` list in `autoload/game_state.gd` (label, station, game, cookware, optional ingredient `models` and `rounds`).

## Customer bubbles
Each customer's speech bubble shows a **picture of the food they want**, a **mood face**, a **patience bar** and a short caption.
The bubble tints and the face changes as patience runs down: happy (green), neutral (yellow), worried (orange, wobbles), angry (red,
shakes). A pulsing **"!"** badge means they're waiting for someone to take their order; while eating they show a happy "yum" face.
Nearer bubbles draw on top of farther ones, and the bubbles of a party sit at different heights. The faces, bubble and badge are drawn
in code (`scripts/mood_icons.gd`); the food pictures are the dish models rendered once and reused (`scripts/food_icons.gd`).

## Tables, chairs and parties
Tables and chairs are bought **separately** in build mode:

1. **Tables** come in three sizes (**Table for 2 / 4 / 6**) and are placed **without chairs**.
2. **Chairs** are their own item ($25). Hold a chair and a ghost snaps to the nearest **free chair spot** around a table (yellow
   discs mark the free spots). Click to place it.
3. **A table only holds as many chairs as it seats**: a table for 4 takes at most 4. A full table refuses more ("already has
   all 4 chairs"), and chairs can't be placed away from a table.
4. You can **move** a chair (click it, then place it at another table's free spot for free; right-click or Esc puts it back) and
   **sell** it (right-click it for half the price).
5. **Selling a table** (right-click it) gives back half its base price **and sells its chairs too** (half of each chair's price).
   Tables and chairs can't be moved or sold while customers are sitting at that table, and you can sell any table, including the
   starter ones.

The two starter tables come with all their chairs. Saves from before this change keep all their chairs too.

Customers arrive as **parties** of 1 up to the number of **chairs** a table has (not its size), on random chairs, so a table for 4
with 3 chairs hosts 1, 2 or 3 people. A table with no chairs seats nobody. Everyone in a party orders, waits, eats, pays and leaves on
their own, and the table counts as busy until the *whole* party has gone. Tickets, plates and burner labels show the chair an order
came from: `T3-B` means table 3, chair spot B.

**How many tables you can have** depends on the size of your restaurant: **4 in the starting room, +3 for every expansion** you buy
(so 7, 10, 13 ... up to 28). The build menu and shop show the limit, and a 5th table in the starting room is refused until you expand.
Selling a table frees up room for another.

- The chair model is whatever you set on the `ChairModel` node in `scenes/table.tscn`; every chair uses it.
- A table keeps its chair spots clear in build mode (its footprint includes them), so a chair you've paid for always has room.
- The ticket board holds 16 tickets (two rows) and the order-up table 16 plates (two rows). If a big party fills them,
  extra orders wait in a queue and appear as space frees up, so nothing gets lost.
- Idle (offline) income counts the chairs you own, so more chairs earn more.

## Build mode (press V)
Buy, place, move and sell tables and decor. You can still walk around with WASD while building.

| Key | What it does |
|---|---|
| 1-9 or mouse wheel | Choose an item from the list on the left |
| Left click | Place the held item. With empty hands: pick up a table or decor to move it (moving is free) |
| R | Rotate 90 degrees |
| Right click | Cancel what you're holding. With empty hands: sell decor for half its price |
| V or Esc | Leave build mode (your layout is saved) |

A ghost follows your crosshair on the floor, snapped to a grid: green means you can place it, red means you can't
(the reason is shown: not enough money, outside the restaurant, too close to the entrance, something in the way,
or you're standing there). The kitchen is off limits.

- **Tables** come from the pool of table spots in `scenes/main.tscn` (the Tables node), without chairs. Choose Table for 2, 4 or 6 when you buy; then place it anywhere. Bigger tables need more floor (their chair spots included). Buy chairs separately (see below). You can move and sell tables, but not while anyone is sitting at them.
- **Stoves and counters** can be bought and placed too: a stove adds 4 burners ($250), a prep counter adds 2 prep spots ($120). They
  can go anywhere there's room, but not on top of the ticket board, the order-up table, the starter stove / counter or the staff's
  spots (those stay protected). A station with food on it can't be moved or sold.
- **Decor** raises your *decor appeal*: every point adds +1% to tips (max +50%). It also blocks you from walking
  through it, except rugs.
- Customers and staff walk in straight lines, so they can walk through decor.

- **The grid.** Everything snaps to a 0.5 grid, and a faint grid is drawn on the floor while you build (brighter lines every 1.0,
  fading away from your crosshair). The starter stove, counter and order-up table are snapped to the same grid, and stoves and
  counters are whole grid cells wide (stove 1x1, counter 2x1), so you can put them **edge to edge**: stoves in a row, a counter
  against a stove, and so on. Only the ticket board's standing space, the cooks' and waiters' spots and the order-up table's
  pickup area stay protected.

To add or change items, edit `scripts/build_catalog.gd` (name, cost, appeal, model files, size). The build area, door
clearance and sell refund are in the BuildMode node's script (`scripts/build_mode.gd`) as exported values.
Build sounds are in `scenes/build_sounds.tscn` (BuildToggle, BuildSelect, BuildRotate, BuildPlace, BuildSell,
BuildError): drag a .wav / .ogg onto a node's Stream slot, like in `game_sounds.tscn`.

## Seating
Customers sit with their hips at the chair seat. The height comes from the **SeatPoint** marker in `scenes/table.tscn`
(move it up or down; if it is left on the floor, the table's "Seat Height" value is used). The game also measures the
character's hip bone to line the pose up with the seat. If it still looks off, select the customer scene's root node and
adjust **Sit Offset Extra** (or **Hip Above Seat**) in the Inspector.

## Adding the Kenney assets (CC0)
Download the packs from kenney.nl and copy the `.glb` files into:

    assets/mini-characters/   (Mini Characters)
    assets/food-kit/          (Food Kit)
    assets/furniture-kit/     (Furniture Kit)
    assets/mini-shop/         (Mini Shop, not used yet)

Then let Godot import them. Any path that doesn't exist falls back to a colored box.
The filenames I used are guesses, so if a model shows up as a colored box, select its ModelSlot in the scene
and point **Model Path** at the right file (see the section above). Dish models are in `autoload/game_state.gd`.

## CrazyGames (web build)
The game is set up to ship on CrazyGames as an HTML5 build.

**Build it:** run `powershell -ExecutionPolicy Bypass -File tools/export_web.ps1`. It exports the
"CrazyGames (Web)" preset to `build/web/` and zips it as `build/restaurant_tycoon_web.zip` (upload that zip).
To try it locally: `cd build/web` then `python -m http.server 8765` and open http://localhost:8765 in Chrome.
On localhost the SDK runs in test mode and shows fake ads.

| What | Where |
|---|---|
| Renderer | Compatibility (the only one that runs in browsers). Set in `project.godot`. |
| Web export | `export_presets.cfg`: single-threaded (no special server headers needed), SDK loaded via **Head Include** |
| SDK glue (JavaScript) | `web/crazygames_head.html` (copy into the preset's Head Include if you change it) |
| SDK calls from GDScript | `autoload/crazy_games.gd` (`CrazyGames` autoload). Safe no-ops in the editor / desktop. |
| Start screen, pause menu, settings | `scripts/pause_menu.gd` (P pauses; volume, music, mouse sensitivity) |

What the SDK is used for:
- **loadingStop** once the save is loaded, **gameplayStart / gameplayStop** when you play / pause / open the shop.
- **Saves** go to CrazyGames' Data storage (synced to the player's account) as well as `user://save.json`.
  The game also saves when the tab is hidden, since browsers never send a close request.
- **Rewarded ads:** "2x cash for 3 min" (start / pause menu; the timer only runs while playing) and
  "double your welcome-back money" (start screen, when you earned money offline).
- **Midgame ads** only on a rank up, never in the first 2.5 minutes, at most every 3 minutes.
  The game pauses and mutes during every ad. **happytime** fires on rank up.
- **Mouse lock:** browsers release the mouse on Esc and need a click before locking it, so whenever
  the mouse gets released the pause menu appears; B opens the shop on the web (Esc can't).

Before submitting: mark the game desktop-only (it needs keyboard + mouse), add a cover image and a short
controls description, and test the zip in CrazyGames' QA tool / preview.

## Next steps
- Play the Mini Characters walk/idle animations with an `AnimationPlayer` found inside the model.
- Replace straight-line walking with `NavigationAgent3D` once you add walls.
- Free-placement build mode on a grid using the Furniture Kit and Mini Shop pieces.
