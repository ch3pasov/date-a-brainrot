# Supplying character art locally

The public asset XML contains only folders, with no mesh, texture, animation,
image, or external asset reference. With that container, the client creates
original toy stand-ins from plain Parts. Each personality has its own accessories;
variant colors and date/photo gestures work without external character art.

Supplying a visible Model replaces its stand-in automatically. Missing, empty,
entirely invisible, or non-Model templates use a stand-in. After preloading, a
confirmed Failure or TimedOut status for a required mesh also activates a stand-in
in portraits and scenes. Failed textures do not discard loaded geometry. Unknown
mesh statuses keep the supplied model, and a later view can retry a failed load.
These paths are tested with controlled service responses; no live permission or
asset-rendering result is implied by the offline checks.

The game expects `ReplicatedStorage.BrainrotAssets` to contain:

```text
BrainrotAssets
  Models
    <modelName from src/shared/Catalog.luau>
  Clips
    <same modelName>
      idle       (optional KeyframeSequence)
      greeting   (optional KeyframeSequence)
```

Use your own art or acquire models under terms covering your intended Roblox use.
The private release's pack is identified in THIRD_PARTY.md for provenance only;
it is neither downloaded nor granted a new license by this repository.

Prepare display models without executable scripts, PackageLinks, or unrelated
effects. Keep the model's pivot and dimensions appropriate for a viewport, and
check every mesh/texture dependency in your own published game. Optional animation
sequences must fit the model's joints. Imported models are third-party input;
review them before executing or publishing anything.

Save a locally prepared collection to `assets/BrainrotCollection.rbxmx` and rebuild
with Rojo. Keep that local replacement out of public commits unless redistribution
is expressly permitted. A successful build does not establish art rights or prove
live asset permissions. The public verification workflow never publishes a game.
