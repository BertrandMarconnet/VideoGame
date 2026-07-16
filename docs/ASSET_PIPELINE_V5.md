# Blackout Protocol — Asset Pipeline V5

The single supported entry point is `.github/ISSUE_TEMPLATE/generate-game-asset.yml` or the visual configurator published at `asset-generator.html`.

A validated bundle contains:

- `<slug>.glb` — visible gameplay geometry and rig only;
- `<slug>.png` — preview;
- `<slug>.asset.json` — Godot catalogue entry;
- `<slug>.damage.json` — localized material/detachment rules;
- `<slug>.audio.json` — animation/audio markers;
- `audio/` — generated or uploaded WAV/OGG/MP3 clips;
- `<slug>.sanitize.json` — proof that preview and collision proxy meshes were removed from the visible GLB;
- `<slug>.validation.json` — final automated validation report.

Collision proxies are gameplay metadata and must never be exported as visible meshes. The sanitizer clears any node named `*-colonly`, `*_colonly`, `PreviewGround` or using `CollisionHidden` material. The validator rejects a bundle if one of those nodes still owns a mesh.

Animation sound markers use a normalized time in `[0,1]`, for example:

```text
walk = step @ 0.18
walk = step @ 0.68
attack = impact @ 0.46
idle = servo @ 0.00 @ loop
```

The Godot runtime attaches `GeneratedAssetAudio` automatically when a catalogue entry exposes `audio_profile`.
