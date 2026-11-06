# Date a Brainrot

A small Roblox game about improbable matches: swipe, exchange scripted messages,
respond during a video call, and remember a sequence of objects on a date.
Complete a meeting to keep a selfie with your avatar, the character, and the place.

[Play on Roblox](https://www.roblox.com/games/114564825581977)

Roblox restricts the live game to eligible players aged 18 and older. This public
repository contains the project's original gameplay, interface, procedural scenery,
and tests. **Third-party character art is not included.** The live game uses models
obtained through Roblox Creator Store; those files are not licensed here.

## Development update — November 6, 2026

Completed stories now unlock two optional date remixes: a six-item order and a
reverse-order memory game. Collect six illustrated souvenirs per story, one for
each location and mode. Scores and souvenirs persist separately from the original
selfie and best scores. Retries are unlimited and never remove earned progress.
The album suggests unvisited places, tracks souvenirs and adapts text spacing on
small screens. A replay proposes a new place while keeping your manual selection.
Consecutive correct answers get personality-specific cheers. Earned souvenirs can
be pinned as stickers on story photos, replaced or removed without spending them.
All 34 characters now have a personal follow-up story in chat. Reply buttons fit
the measured text, and short windows scroll instead of clipping longer answers.

Dates now wait for a ready button after a short rules card. Retrying a lost start response keeps the same round and order.
Round results scroll on compact screens while actions remain accessible; text and
photo spacing adapt to the window and preserve the reading position.

The photo booth previews four static poses and three frames earned through story
progress: all venues, three perfect stages, or all six souvenirs. Changes save only
when requested and preserve the avatar, photo location, records, and sticker. The preview stays visible while poses and frames scroll, so each choice can be seen immediately.

The album Ideas board suggests up to three next activities from existing progress,
with direct routes to unfinished stories, new venues, missing souvenirs, perfect
scores and the photo booth. Goals have no expiry or separate currency.

Personal conversations now include 68 answer-specific punchlines for the odd
choices, kept with the selected text when answers shuffle. Scoring stays the same.

Missing character models now use original procedural toy stand-ins with six
personality accessories, variant colors, and date/photo gestures. Supplied models
remain preferred. The fallback needs no meshes, textures, or animation assets.
Empty/invisible templates and confirmed remote mesh failures also use stand-ins;
texture failures retain successfully loaded geometry. Late loads respect view disposal.

Quiet feedback now also stops portrait rotation, decorative orbits, and animation
tracks. Hidden portraits pause tracks; resuming live feedback restores movement.

Completed dates with mistakes now compare the planned items against your choices.
Reverse rounds show the reversed answer order explicitly; perfect rounds omit the
review. It is result-only and does not change saved scores or rewards.

Earned remix souvenirs now also prove a visit to their venue, including older
saves. Travel frames unlock without repeating ordinary dates at the same places.
Saved selfie identity stays intact, and remix-result text expands to fit.

Each character now has a short personal ending for the first selfie, echoing their
conversation. The same memory appears in the wide story book; replay results keep
the record-focused message. These 34 endings add no saved-profile fields.

Date demonstrations also pause when the window loses focus or the Roblox menu
opens. Returning replays the current cue in full, even if no frames ran while
the game was hidden. Earlier cues and completed reveals are preserved.

Completing or replaying a story opens the album at that photo, including the right
page and scroll position. A highlight identifies it; later resizing keeps the
player's reading position.

The Ideas board can cycle through other eligible stories, including photo sessions
for completed collections. It keeps the chosen set when the window changes and
shows the extra button only when alternatives exist.

Video calls measure gesture labels and response text before laying out cameras.
Short phones use the available width and put cameras side by side when needed.
A confirmed wrong answer names the requested gesture and survives resizing.

Successful remixes offer the next missing souvenir and name its venue and mode.
The completed set leads to a preview of its earned photo frame. Failed attempts
still offer the same round, and the collection keeps every replay accessible.

419 offline checks and both source builds pass. The full-catalog simulation covers
136 stories, 1,224 rounds and 816 souvenirs across a saved-profile JSON roundtrip. New UI geometry and actions are
checked on small and wide layouts; Roblox rendering and live persistence have
not been playtested for this update. The live version below is a separate release.

New photo frames appear as rewards in the round result, with a shortcut to try
them in the booth. The server reports only frames unlocked by that round; preview
does not save the style automatically. Every story is checked to award all three once.

Match and return letters measure long names and captions, keep readable text on
short screens, and preserve scroll position while their actions remain accessible.

Notifications wait for the active window and a closed Roblox menu. Their reading
time pauses while hidden, and a notice over the memory game pauses its current cue.

## Released checkpoint

- Live Roblox place version: **29**.
- Gameplay source: `f8bfedf08efe3112edcc289274b941adfe6c38a6` in the private development history.
- Original-source checkpoint: `c6731f75c8798a9f87f014696e8d9e16442ac1a8`.
- 285 offline checks passed for the original release. Its chat, call, park date,
  selfie, and ordinary-rejoin persistence were checked in Web Play.
- This repository starts with a new history and an empty asset container. It is
  a source release, **not an export of the live game's models or player data**.

## Build and check

Install [Rokit](https://github.com/rojo-rbx/rokit) and the tool versions pinned in
`rokit.toml`, then run:

```sh
rokit install
python3 prototype/tools/check_background.py --output /tmp/date-brainrot-checks
```

Choose a new or empty output directory. The command runs the Luau and Python
checks and produces binary and XML Roblox places without launching Studio.
The checked-in empty `assets/BrainrotCollection.rbxmx` allows a source build;
character viewports remain empty until you supply appropriately licensed models.
See [ASSET_SETUP.md](ASSET_SETUP.md).

## Play

Use the on-screen controls or keys 1–3 for responses and gestures, 1–4 for date
objects, and Space to wave. The guide contains sound and reduced-motion controls.
Best scores and completed meetings persist; a retry does not erase a better score.

## Rights and scope

See [THIRD_PARTY.md](THIRD_PARTY.md) for the art boundary and
[COPYRIGHT.md](COPYRIGHT.md) for source rights. Free Creator Store access is not
treated as permission to redistribute someone else's art on GitHub. No claim is
made to ownership of meme characters, Roblox, or player-created avatar assets.

The project is released as a prototype. Physical-device performance, audio QA,
independent friend access, and visual polish remain limited; see
[RELEASE_NOTES.md](RELEASE_NOTES.md). Development resumed on November 6, 2026.

