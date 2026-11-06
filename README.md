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

The changes below are on `codex/playful-replays-2026-11-06` and have **not been
published to Roblox**. The live release is a separate checkpoint.

- **More to do after a selfie.** Two optional date remixes add a six-item order and
  reverse-order memory. Collect six illustrated souvenirs per story across three
  venues, with separate records and unlimited retries that preserve earned rewards.
  A successful round offers the next missing souvenir; a complete set leads to its
  earned photo frame. Remix wins also count toward visited venues.
- **Personal character moments.** All 34 characters have a personal chat story,
  with 68 answer-specific punchlines for odd choices and 34 first-selfie endings.
  The same photo memory appears in both phone and wide story books.
- **Your own postcard.** The photo booth offers four poses and three frames earned
  through story progress. Pin, replace or remove an earned souvenir as a sticker
  without consuming it. Preview choices before explicitly saving them; the avatar,
  photo location and records stay with the story.
- **A clear next activity.** Ideas suggests up to three unfinished stories, venues,
  souvenirs, records or photo sessions from existing progress. More Ideas cycles
  through other eligible stories. These goals have no expiry or separate currency.
- **Readable controls and continuity.** Cards, rules, results and collections fit
  measured text on compact screens. Reading positions survive resizing; completed
  rounds focus the correct album photo. Dates wait for readiness, pause their
  demonstration when hidden or covered by menus, and explain mistakes afterward.
  Notifications wait for visible reading time. Guides explain keyboard controls
  and quiet feedback stops portrait movement.
- **Original fallback figures.** Missing, empty or unusable character templates use
  procedural toys with personality accessories, variant colors and gestures.
  Confirmed mesh failures also use stand-ins; texture failures retain loaded
  geometry. The fallback needs no external character meshes or animations.

**Validation:** 440 offline checks, 61 compiled source files and both source builds
pass. The full-catalog simulation covers 136 stories, 1,224 rounds and 816 souvenirs
across a saved-profile JSON roundtrip. UI checks exercise geometry, text and actions
on compact and wide layouts. These checks and approximate layout previews do not
establish Roblox rendering, live storage or physical-device performance for this
update; it has not had a live playtest.

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
The checked-in empty `assets/BrainrotCollection.rbxmx` builds with original
procedural toy characters. You can supply appropriately licensed models to replace
them; see [ASSET_SETUP.md](ASSET_SETUP.md).

## Play

Use the on-screen controls or these keyboard shortcuts:

- Left / Right: skip / like the current feed card.
- 1–3: choose the matching response number or a gesture from left to right.
- Enter: start a ready date; after the demonstration, 1–4 selects a numbered object.
- Space: choose the first gesture during a call.

The guide contains sound and quiet-feedback controls. Best scores and completed
meetings persist; a retry does not erase a better score. Open a saved story in the
album for replays, remixes and the photo booth, or use Ideas for a suggested goal.

## Rights and scope

See [THIRD_PARTY.md](THIRD_PARTY.md) for the art boundary and
[COPYRIGHT.md](COPYRIGHT.md) for source rights. Free Creator Store access is not
treated as permission to redistribute someone else's art on GitHub. No claim is
made to ownership of meme characters, Roblox, or player-created avatar assets.

The project is released as a prototype. Physical-device performance, audio QA,
independent friend access, and visual polish remain limited; see
[RELEASE_NOTES.md](RELEASE_NOTES.md). Development resumed on November 6, 2026.

