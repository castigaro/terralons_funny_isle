# Assumptions – Terralon's Funny Isle 2

Assumptions the discovery roles made that the binding constraints and the confirmed assumptions do not cover. Open rows are ordered by risk: the assumption that would change the product most if it were wrong comes first.

| # | Assumption | Role | Reason | Status | Correction |
|---|---|---|---|---|---|
| 1 | Star rating: 1 star for the required tasks, 2 stars for all tasks, 3 stars for all tasks with generous time left; each level therefore has required and optional tasks | Product management/BD | The constraints name the inputs (tasks done, time left) but not the thresholds; this scheme defines the whole scoring and level design | confirmed | |
| 2 | Random events run on fixed or seeded per-level schedules with some timing variation, never truly random, so 3-star runs do not depend on luck and the bot playthrough stays reliable | Product management/BD, Support+Sales, Customer/User | Fairness for replaying players and a deterministic proof that every task is completable | confirmed | |
| 3 | The castaway carries one item or animal at a time; crafting and inventory slots from v1 are dropped | Product management/BD, Reference analysis | Keeps the real-time loop fast and readable; inventory and recipes are not named by the constraints | confirmed | |
| 4 | Audience is casual players aged roughly 8 and up, plus families playing together, on a Windows PC | Market, Customer/User, Support+Sales | Sets difficulty, text amount, tone and timer generosity; inferred from "family-friendly" | rejected | Players aged 8 and up including teens and adults who like hectic party chaos (Overcooked, Untitled Goose Game, Moving Out); families are welcome, but difficulty and pace target action fans, not cozy players |
| 5 | Soft-lock prevention: items and animals that become unreachable (stuck behind walls, thrown into the sea) respawn or reset, so every task stays completable after the worst event | Support+Sales, Customer/User | Required to honour "every task can be completed"; the mechanism itself is not specified | confirmed | |
| 6 | Events add chaos but never decide the stars alone and never cause a level loss by themselves | Support+Sales, Market | Avoids frustration; timer pressure plus events could otherwise feel unfair | confirmed | |
| 7 | No tutorial: level 1 teaches the controls through its layout and short contextual prompts | Support+Sales | Persona pain point "tutorial walls"; onboarding is not covered by the constraints | confirmed | |
| 8 | The level timer stops during pause and menus; one key restarts the level instantly | Support+Sales, Customer/User | Fairness and fast retry; not specified in detail by the constraints | confirmed | |
| 9 | Every failure shows a short cue saying why it happened, in addition to the funny reaction | Support+Sales | Persona pain point "failing without knowing why" | confirmed | |
| 10 | Star thresholds are visible before and during play; the result screen is short | Support+Sales, Customer/User | Players aiming for 3 stars need the goals up front | confirmed | |
| 11 | On-screen effects and repeated sound effects are capped or throttled; announcer lines never overlap | Support+Sales, Customer/User | Keeps the chaos readable and the mix clean | confirmed | |
| 12 | Sessions are 5–10 minutes, with retries to earn 3 stars | Market, Product management/BD | Replay value of a 20–30 minute game rests on star goals | confirmed | |
| 13 | Each task keeps a hint, carried over from the v1 task engine | Product management/BD, Reference analysis | Helps young players; hints are not named by the constraints | confirmed | |
| 14 | Level progress (unlocks, best stars) is stored in a local JSON file next to settings.json in the overridable data folder | Product management/BD | Reuses the v1 settings pattern; the storage format is not specified | confirmed | |
| 15 | Stable framerate (target 60 fps) at 1920x1080 and 1280x720 without physics jitter | Support+Sales, Customer/User | Real-time action and comic timing depend on it; no number is set by the constraints | confirmed | |
| 16 | Menus are simple, icon-first and mouse-friendly | Support+Sales | Young players and text-light menus | confirmed | |
| 17 | The plugin architecture of v1 is dropped; only the EventBus idea is kept | Product management/BD, Reference analysis | Too heavy for a real-time game; architecture is not covered by the constraints | confirmed | |
| 18 | A gamepad is a nice-to-have and not in scope for the first release | Market, Product management/BD | Keyboard first is confirmed; gamepad support is not mentioned | confirmed | |
| 19 | No leaderboards or online features | Market, Product management/BD | Offline is binding; online extras are not explicitly excluded | confirmed | |
| 20 | Best time and best stars per level are shown (could-have) | Support+Sales | Replay value for completionists | confirmed | |
| 21 | Distribution is free or a small indie release outside any store; a hobby-scale product with limited discoverability | Market, Product management/BD | No store, monetisation or marketing requirements | confirmed | |
| 22 | A notable share of players are German speakers and play in German (persona "Lena"); English stays the default | Customer/User | Raises the importance of the German no-clip check | confirmed | |
| 23 | Personas include a completionist/speedrunner who replays levels for 3 stars and notices bugs | Customer/User | Drives determinism and visible thresholds | confirmed | |
