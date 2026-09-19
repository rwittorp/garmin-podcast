# Garmin Podcast App — Project Log

Audio Content Provider app that downloads and plays podcasts on Garmin watches.
Target device: **Forerunner 245 Music** (240x240, Connect IQ 3.3, ~3.5GB music storage).
Repo: https://github.com/rwittorp/garmin-podcast
Live feed: https://rwittorp.github.io/garmin-podcast/feed/episodes.json

## Architecture

- `source/` — Monkey C app, type `audio-content-provider-app` (required: only this
  type can download audio + feed the native media player).
- `proxy/server.py` — local RSS→JSON dev proxy (`/episodes`).
- `proxy/fetch.py` + `.github/workflows/update-feed.yml` — hourly static
  `feed/episodes.json` regeneration, served over GitHub Pages HTTPS.
- The watch fetches a compact JSON episode list (it cannot parse the 1.9MB RSS XML).
  Static `Episodes.CATALOG` in `Constants.mc` is the offline fallback.
- Feed: Defector flagship (ART19) `https://rss.art19.com/the-distraction`
  (channel currently titled "All Ball"). Enclosures go through 5 tracking
  redirects — proven OK for the watch downloader. Full episodes ~100MB.

## Milestones

- [x] Scaffold audio provider project for fr245m (manifest, views, delegates)
- [x] Fix SDK 9.2 build breaks: launcher icon, `Media.SyncDelegate` →
      `Communications.SyncDelegate`, CheckboxMenuItem casts, `typecheck = 0`
- [x] Simulator: sync-config → sync download (`code=200`) → playback config → playback
- [x] Real Defector trailer downloads + plays (ART19 redirect chain OK)
- [x] Live JSON episode list from local proxy in sim
- [x] Cleanup: printlns removed, 40x40 icon, clean build
- [x] GitHub repo + Pages + hourly feed workflow — feed live at
      https://rwittorp.github.io/garmin-podcast/feed/episodes.json (verified)
- [x] Production path proven in sim: Pages HTTPS list renders, strict HTTPS on, no proxy
- [ ] On-device test — BLOCKED on USB cable (Mac sees no Garmin on USB bus;
      watch shows power icon only). Retry with Garmin data cable, direct port.
- [ ] Store publishing

## Frequent commands

```zsh
cd /Users/randywittorp/Dev/GarminPodcast

# Build
SDK=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
"$SDK/bin/monkeyc" -o bin/PodcastPlayer-fr245m.prg -f monkey.jungle -y ~/garmin-developer-key.der -d fr245m
# (with ~/.zshrc PATH export: monkeyc ... / monkeydo ... / connectiq)

# Simulator
connectiq                                                      # launch (logs stream here)
monkeydo /Users/randywittorp/Dev/GarminPodcast/bin/PodcastPlayer-fr245m.prg fr245m

# Local proxy
python3 proxy/server.py                                        # -> http://127.0.0.1:8000/episodes
python3 proxy/fetch.py --out feed/episodes.json --limit 10    # regenerate static feed

# Git
git push -u origin main   # first time; afterwards plain: git push
```

`~/.zshrc` PATH (new shells need `source ~/.zshrc` or a fresh terminal):
```zsh
_ciq_sdk=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
export PATH="$_ciq_sdk/bin:$PATH"
```

## Simulator test flow (audio apps have 4 modes)

Push once first (mode menu needs an installed app), then repeat per mode:
**set `Settings > Media Mode > X`, then push.**

1. **Sync Configuration** — check episodes → Done → app exits (by design).
2. **Sync** — downloads; expect `toSync=1`, `code=200`, `stored songs=1`.
3. **Playback Configuration** — check downloaded episodes → Done.
4. **Playback** — controls work; simulator is always silent (normal).

New terminals start in `~` — `cd` to the project or use absolute `.prg` path.

## After a Mac restart

```zsh
cd /Users/randywittorp/Dev/GarminPodcast
source ~/.zshrc            # if monkeydo/connectiq not found
connectiq                  # launch simulator (logs stream here)
# new terminal:
cd /Users/randywittorp/Dev/GarminPodcast
monkeydo /Users/randywittorp/Dev/GarminPodcast/bin/PodcastPlayer-fr245m.prg fr245m
git -C /Users/randywittorp/Dev/GarminPodcast pull   # pick up anything pushed
```

## On-device test (pending — needs working data cable)

1. Confirm mount: GARMIN volume in Finder (`diskutil list external`,
   `system_profiler SPUSBDataType | grep -i garmin`).
2. Copy: `cp bin/PodcastPlayer-fr245m.prg /Volumes/GARMIN/GARMIN/Apps/` (verify
   exact Apps path on the mounted volume first with `ls`).
3. On watch: join Wi-Fi, pair Bluetooth headphones.
4. Same 4-step flow as sim, starting with the trailer episode (not a 100MB one).

## Gotchas learned

- CheckboxMenu: checked = keep/download, **unchecking a pre-checked box queues a DELETE**.
  Both top+bottom "Done" entries are framework-drawn; either confirms.
- `Communications.startSync()` is a no-op in the simulator — use the menu-driven flow.
- fr245m is button-only: arrows/Enter in sim, mouse clicks do nothing.
- Each `monkeydo` prints `init` twice — normal.
- Sim beachball → `pkill -9 -i connectiq`, relaunch.
- Uncheck `Settings > Use Device HTTPS Requirements` only for `http://localhost` proxy
  testing; keep checked for production HTTPS (watch requires HTTPS).
- `File > Edit Persistent Storage` shows app *settings*, not the object store —
  useless for debugging SONGS/SYNC_LIST.
- Full episodes ~100MB: fine on watch Wi-Fi eventually, painful in sim. Test with trailers.
- Remaining build warnings (deprecated getProperty, container-access) match Garmin's own
  sample patterns — benign under `typecheck = 0`.
