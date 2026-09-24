# Credits

Spenn's code, visuals and fonts are covered in the repository itself; the
third-party media below are used under their licences. The source packs are
processed by `tools/import_assets.py` (trim, fades, loudness matching,
re-encoding, seamless loops, texture downsizing). Nothing else is changed.

## Music — CC BY 4.0

- «Mesmerizing Galaxy» (loop version), Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/play.ogg`
- «Envision», Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/menu.ogg` (loop crossfade baked in)

The attribution is also shown in the game, under Settings.

## Sounds — CC0 1.0

By Kenney (www.kenney.nl), public domain (CC0 1.0):

- Interface Sounds — clicks, ticks, plucks, scratches, toggles, UI moves
- Impact Sounds — plate, soft, glass, metal, wood, punch impacts
- Music Jingles — Pizzicato and Steel jingles (intro, reveal, clear, record,
  lose, boss)
- Impact Sounds (again) — wood and heavy metal for rigid shells
  (`wood_*`, `metal_*`)
- RPG Audio — drawKnife (a hook sliding along the rail) and creak (a string
  pulled up) for enemy evasion

→ `assets/sfx/*.ogg`. The whoosh (`assets/sfx/whoosh_*.ogg`) is generated
by `tools/import_assets.py`.

## Sounds — freesound.org, CC0 1.0

Jelly (soft-body) hits and bursts, from the HQ previews, trimmed and
loudness-matched by `tools/import_assets.py`:

- «Slime Squish» by qubodup — https://freesound.org/s/442772/
- «Gel Splats.wav» by mincedbeats — https://freesound.org/s/593984/
- «Slime slapping» by greenlinker — https://freesound.org/s/794272/
- «Cartoon Splat» by Breviceps — https://freesound.org/s/445117/
- «Cartoon - Splat!» by Breviceps — https://freesound.org/s/445118/
- «Step on a slug (Splat!) 1» by Breviceps — https://freesound.org/s/447929/

→ `assets/sfx/squish_*.ogg`, `assets/sfx/splat_*.ogg`

## Particles — CC0 1.0

Kenney Particle Pack (www.kenney.nl), public domain (CC0 1.0):
smoke_04, smoke_07, trace_06, circle_04, circle_05
→ `assets/particles/*.png` (downsized, white on alpha, tinted in game).

## Fonts — SIL Open Font License 1.1

Fraunces and Manrope, from google/fonts; licences in `fonts/`.
