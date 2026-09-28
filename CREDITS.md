# Credits

Spenn's code, visuals and fonts are covered in the repository itself; the
third-party media below are used under their licences. The source packs are
processed by `tools/import_assets.py` (trim, fades, loudness matching,
re-encoding, seamless loops cut on the bar, noise cleaning of the laughs,
texture downsizing). Nothing else is changed.

## Music — CC BY 4.0

- «Mesmerizing Galaxy» (loop version), Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/play.ogg`
- «Dreamy Flashback», Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/menu.ogg` (loop crossfade baked in)
- «Brain Dance», Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/lift.ogg` (changed: a 32-bar loop cut from 0:29.5)
- «Cephalopod», Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  → `assets/music/boss.ogg` (changed: a 16-bar loop cut from 0:35.3)

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

The enemies' mocking laughs, cut from the HQ previews, high-passed, cleaned
of background hiss (a gentle spectral gate), trimmed at a gap between
syllables and loudness-matched by `tools/import_assets.py` (`build_laughs`):

- «Very Cute Cartoon Laughter» by NicknameLarry — https://freesound.org/s/513983/
- «cute giggles.wav» by martian — https://freesound.org/s/19260/
- «Laughter of a small creature» by BloodPixelHero — https://freesound.org/s/576984/
- «Cartoon giggle laugh high pitch» by JohnsonBrandEditing — https://freesound.org/s/243378/
- «Imp Laugh» by scorpion67890 — https://freesound.org/s/205751/
- «Impish Laugh» by ChuckChuckGoof — https://freesound.org/s/580747/
- «Witch Cackle» by AntumDeluge — https://freesound.org/s/417826/
- «Funny snickering man laughing» by jyveeanimate — https://freesound.org/s/702394/
- «Goblin_Various Laughs and Giggles.mp3» by SnowFightStudios — https://freesound.org/s/643664/
- «Cartoon Laugh» by JohnsonBrandEditing — https://freesound.org/s/173933/
- «troll heh.wav» by Reitanna — https://freesound.org/s/343981/
- «Mocking Laughter» by CreepyKing — https://freesound.org/s/842291/
- «Condescending MOcking Laugh.wav» by akapastels — https://freesound.org/s/697899/
- «Mocking Laughter» by Apheo — https://freesound.org/s/382906/
- «Man Laugh» by NinjaSharkStudios — https://freesound.org/s/649082/
- «Evil Laugh» by balloonhead — https://freesound.org/s/362330/
- «Evil Laugh» by ckvoiceover — https://freesound.org/s/401332/
- «evil laugh» by riippumattog — https://freesound.org/s/704363/
- «Evil Laugh 1.wav» by 222laurio — https://freesound.org/s/466059/
- «Evil Laugh_1.wav» by NinjaSharkStudios — https://freesound.org/s/646307/

→ `assets/sfx/laugh_*.ogg` (their loudness curves in `scripts/laughs.gd`)

## Particles — CC0 1.0

Kenney Particle Pack (www.kenney.nl), public domain (CC0 1.0):
smoke_04, smoke_07, trace_06, circle_04, circle_05
→ `assets/particles/*.png` (downsized, white on alpha, tinted in game).

## Fonts — SIL Open Font License 1.1

Gluten (Etcetera Type Co.) and Nunito (Vernon Adams et al.), from google/fonts, SIL OFL 1.1; licences in `fonts/`.
