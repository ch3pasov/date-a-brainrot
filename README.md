# Date a Brainrot

A small Roblox game about improbable matches: swipe, exchange scripted messages,
respond during a video call, and remember a sequence of objects on a date.
Complete a meeting to keep a selfie with your avatar, the character, and the place.

[Play on Roblox](https://www.roblox.com/games/114564825581977)

Roblox restricts the live game to eligible players aged 18 and older. This public
repository contains the project's original gameplay, interface, procedural scenery,
and tests. **Third-party character art is not included.** The live game uses models
obtained through Roblox Creator Store; those files are not licensed here.

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
[RELEASE_NOTES.md](RELEASE_NOTES.md). No new features are scheduled.
