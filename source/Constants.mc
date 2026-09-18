// Episode catalog for V1.
// V1 uses a static list so no backend server is needed.
// Edit these to your own MP3s (must be HTTPS, direct .mp3 links).
// V2: live list fetched from PROVIDER_URL (proxy/server.py); static
// catalog below is the offline fallback.
module Episodes {
    // Local proxy: python3 proxy/server.py  (then uncheck
    // "Use Device HTTPS Requirements" in the simulator Settings,
    // since this is plain http://localhost)
    // Production feed (GitHub Pages, updated hourly by Actions):
    const PROVIDER_URL = "https://rwittorp.github.io/garmin-podcast/feed/episodes.json";
    // Each entry: { "id", "name", "url", "canSkip", "type" }
    // Keep URLs short; watch Wi-Fi is slow. Start with 1-2 small files for testing.
    const CATALOG = [
        {
            "id" => "ep1",
            "name" => "Sample Ep 1 (3min)",
            "url" => "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            "canSkip" => true,
            "type" => "mp3"
        },
        {
            "id" => "ep2",
            "name" => "Sample Ep 2 (6min)",
            "url" => "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            "canSkip" => true,
            "type" => "mp3"
        },
        {
            "id" => "defector-trailer",
            "name" => "All Ball Trailer (2min)",
            "url" => "https://mgln.ai/e/282/pscrb.fm/rss/p/clrtpod.com/m/tracking.swap.fm/track/IVPmvUWSCISCVAzWNnnJ/rss.art19.com/episodes/05831630-b488-4aa4-921b-445a1335ac4c.mp3?rss_browser=BAhJIhJHYXJtaW5Qb2RjYXN0BjoGRVQ%3D--44e2e32b9acf7092a09102cfd433d86887a2c756",
            "canSkip" => true,
            "type" => "mp3"
        }
    ];
}

// Keys for the object store
module Properties {
    enum {
        AUTHENTICATION_TOKEN,
        SYNC_LIST,
        DELETE_LIST,
        PLAYLIST,
        SONGS,
        APP_VERSION
    }
}

// Bump current to force a storage wipe on upgrade
module Versions {
    enum {
        V1 = 0,
        V2 = 1,
    }
    const current = V2;
}

// Keys for Properties.SONGS entries
module SongInfo {
    enum {
        URL,
        CAN_SKIP,
        ID,
        TYPE
    }
}
