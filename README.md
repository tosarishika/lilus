# Little Us ♡

A cozy, responsive couples web app in plain JavaScript. No build step, no app subscriptions, no paid feature gates.

## Try it

Run `python3 -m http.server 4173` in this folder and open http://localhost:4173. Local mode saves data in your browser. Use **Try as your person** to explore both sides. Browser data does not sync between phones and is removed if browser storage is cleared. Export moments from settings for a backup.

## Connect two phones privately

1. Create a Supabase project and run `schema.sql` in its SQL editor. Use a new project; the SQL creates new tables and functions.
2. Copy the project URL and **publishable key** (or legacy anon key) into `config.js`. Never use the secret or service-role key. Public keys are expected to be visible; database row-level security protects the records.
3. In Supabase Authentication → URL Configuration, set your deployed address as the Site URL and an allowed redirect URL. Email confirmation is supported; confirm your account before signing in.
4. Deploy the folder on Vercel (steps below).
5. On each phone, open the app, choose **Connect your partner**, and create separate accounts. One person creates a space and privately shares the invite code. The other joins it.
6. Set your names on each device. Names are device preferences; the anniversary is shared. Connected accounts use Supabase Realtime for shared updates and a 3-second polling fallback while the app is visible. Shared pet updates wait until a drag finishes and do not reset your drawing. Saved partner doodles appear when you leave and return.

Local moments are kept separate from online data and are not automatically uploaded. Sign out to return to local mode.

## Deploy on Vercel

Upload this folder to a GitHub repository, then import it at https://vercel.com/new. Choose **Other** for framework, leave Build Command empty, set Output Directory to `.` and deploy. If the repository includes the whole workspace, set Root Directory to `little-us`.

Alternatively, run `npx vercel` from this folder, sign in, and follow the prompts. Run `npx vercel --prod` when ready for the production URL. No Vercel credentials are included in this project.

The app has no charges or subscriptions of its own. Vercel and Supabase service limits and pricing apply; review their current plans before choosing them. This project uses no server functions or build dependencies. Online mode loads Supabase JS from esm.sh; font loading uses Google Fonts with local fallbacks.

## Features

- Daily mood check-ins, one per person per day.
- Daily questions; partner answers reveal after your own answer is saved. Online reveal rules are enforced by database policies.
- Would You Rather, preference guessing, and a shared drawing canvas.
- Private chat, love notes, and a memory scrapbook.
- Shared plans, countdowns, anniversary counter, and lists with shared completion toggles.
- Your supplied green dinosaur with a custom name, eight original expression images, five decaying needs, meals, water, treats, baths, play, cuddles, and naps.
- A playable full-screen room: drag food, water, toys, and a sponge to your pet; drag your pet to bed, the bath, or outside; tap controls also work.
- Move the bed, bath, and owned decorations around a shared home.
- A park trail with three stops that either partner can continue, and a completion reward.
- Baby → Young → Grown stages at 100 / 300 love XP, animated reactions, daily care streaks, a pet diary, and a toy-hunt mini-game.
- In-game coins, outfits, room themes, furniture, and a reward when both partners care that day.
- A midnight theme with colorful outlines, labels, and icons.
- Special places with links to OpenStreetMap search.
- Export to JSON from settings.

## Practical limits

Photo and short video uploads are limited to 2 MB each. They are stored as data URLs with the moment, suitable for a small personal collection. Large video libraries need a separate object-storage implementation. Drawings are saved snapshots, not simultaneous live drawing. Places are a list with map links, not an embedded map. The app does not provide native home-screen widgets or push notifications. Chat is protected by account access and row-level security; it is not end-to-end encrypted. The device demonstration lets you switch players and is not an authenticated private account.

## Verification

`node --check app.js` checks JavaScript syntax. Test local mode in your browser. For online acceptance, use two separate browser profiles with separate accounts: pair with an invite, send messages, confirm answer hiding and revealing, try accessing a different couple, and check that a third account cannot reuse the invite. The database cannot be verified without a configured Supabase project.

## Updating an existing setup

Replace the app files. Existing browser moments are preserved. If you already ran the original database schema, run only `pet-migration.sql` in Supabase; do not rerun the full schema. New projects should run `schema.sql`, which includes the pet migration. The old daily bear care records stay in your export; choose your new pet in Our pet & nest to start the expanded system.

Pet needs decay based on elapsed time: fullness 3/hour, water 4/hour, happiness 2/hour, cleanliness 1.5/hour, and energy 2/hour while awake. Sleeping restores energy at 12/hour. Needs stop at zero and your pet never dies. Care actions have a 30-second shared cooldown per action. The first 12 care actions per UTC calendar day award 8 coins and 10 XP each. Both partners caring that day gives 25 extra coins and 20 XP, once. Wake-up does not earn rewards. Outfit and decoration purchases use in-game coins only. Online purchases and adoption are serialized by a database function to prevent simultaneous overspending. Local mode uses the same care rules, but device data can be edited by its owner.

Growth unlocks the next visible size and stage; purchased hats and room items unlock visual variations. Care streaks are shown as encouragement rather than an additional coin reward. Reminders and pet notes appear inside the app. Native phone widgets and background notifications require a native app or a separate notification service and are not implemented here.

Run `node --test pet-engine.test.js` to verify decay, sleep recovery, reward caps, joint care, shopping, growth, and persistence replay. Live database behavior still needs verification in your configured Supabase project.

## Interactive dinosaur room update

The eight supplied PNGs are bundled unchanged in `assets/pet/`: loved, happy, missing, sad, dirty, sleepy, hungry, and bath. Pet needs and recent care pick the image automatically; eating uses the bowl-holding image with a brief nibbling reaction. Existing pets keep their name, care, coins, and growth, and now use your dinosaur artwork. New adoption welcomes this dinosaur directly.

**Existing Supabase project:** run `room-migration.sql` once to update the pet action function and enable Realtime for moments. It works for both the original schema and the previous pet upgrade. Do not rerun the full schema on an existing database. New projects run the latest `schema.sql`, which already includes the room logic. Deploy the entire folder including `assets/`.

**How to play:** open Our pet & nest and use Full screen. Drag your pet into bed to tuck him in, into the bath to wash him, or to the garden door for a walk. Drag a meal, treat, water, ball, or sponge from the tray to your pet. Tap an item and then your pet as an alternative to dragging. Tap the pet without a selected item to cuddle him, or to wake him when asleep.

Use Decorate to drag the bed, bath, or purchased objects to new spots. Get more decorations from Our collection. A basic bed and bath are always available; plants, toys, lamps, rugs, outfits, and room themes use earned coins. Cloud bed is a visual upgrade to the free bed. Each object has one shared position, so the latest saved placement is used if both people move it. Positions are relative to the room, so the same layout works on different screen sizes.

On a walk, drag your pet to the next glowing marker, or tap that marker. Visit all three, then go home to complete the walk. Either partner can continue the saved trail. Returning early skips the completion reward. Shared changes are saved at drop or tap; the other device sees the committed action rather than a live stream of your finger moving. Database row locking protects shared purchases and trail progression. Online cross-device behavior needs acceptance testing against your configured Supabase project; local drag-and-drop and replay logic were checked in the browser and automated tests.

## Cat mood check-ins

The supplied 16-cat sheet is bundled unchanged in `assets/moods/cats.png`. Each expression appears as its own sticker in the mood picker and both partners’ daily check-ins. More little feelings opens the second eight moods. Existing mood records automatically use the matching cat; no database migration is needed. Sharing check-ins across devices uses the existing Supabase setup.

The mood UI now uses `assets/moods/cats-transparent.png`, a transparent cutout created with the built-in imagegen tool. Prompt: remove only the external white background, preserve white fur and all sixteen expressions in the same 4×4 grid. The original sheet remains bundled; CSS adds a 3.5% white backing.

## Pet home and scrapbook update

The pet section now has Home, Shop, Together and Album navigation. Rounded need bars open details. Feed, Play, Bath and Sleep open care trays beneath the room; select and Give is an alternative to dragging. Free meals, biscuits and water are always available. A ball can be dragged to the pet or thrown into the room. Short strokes on the pet give a cuddle. The toy hunt is available in Play.

Bath is a local soap → shower → towel sequence; finishing saves one shared clean action. Dragging the pet into the bath opens that sequence. Bed opens bedtime; drag the blanket onto the pet (or select it and Give) to save sleep. Energy recovers over time on either device. Lamp dimming and the optional synthesized lullaby are local presentation controls. Sound starts only on a tap and stops when the page is hidden.

Shop categories include free food, outfits, furniture, rooms and toys, with previews and buy/equip actions. Together shows both humans, recent care, the daily shared care reward and notes. Album includes adoption, purchases, growth, outfit changes and room makeovers. Photo saves a canvas-rendered illustrated portrait of the home and pet using the current saved outfit and furniture positions; it is a keepsake illustration rather than a browser screenshot. Portraits are stored as ordinary shared memory records and also appear in Memories. No new database migration is required beyond the existing room migration.

The app remains a local preview until final deployment. Completed care, outfits, furniture and album memories use the existing shared event/Realtime setup; intermediate finger movements and bath tool steps are local. Actual two-phone acceptance testing still requires the Supabase configuration.

Profile pictures use the supplied bunny for the girl and fox for the boy, unchanged in `assets/profiles/`. Choose your picture in Settings; your partner gets the matching other picture. Local partner switching swaps the names and pictures together. These preferences are saved on each device.
