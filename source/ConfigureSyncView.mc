using Toybox.Application;
using Toybox.Communications;
using Toybox.Graphics;
using Toybox.WatchUi;

// Sync config: pick episodes. Tries the live proxy first
// (proxy/server.py -> latest Defector episodes as JSON),
// falls back to the static catalog in Constants.mc when offline.
class ConfigureSyncView extends WatchUi.View {

    private var mMenuShown;
    private var mFetching;

    function initialize() {
        View.initialize();
        mMenuShown = false;
        mFetching = false;
    }

    function onShow() {
        if (mMenuShown) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (!mFetching) {
            mFetching = true;
            Communications.makeWebRequest(
                Episodes.PROVIDER_URL,
                null,
                {:method => Communications.HTTP_REQUEST_METHOD_GET,
                 :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
                method(:onEpisodeList));
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.fetchingEpisodes),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onEpisodeList(responseCode, data) {
        var podcasts = normalizePodcasts(responseCode, data);
        if (podcasts.size() == 1) {
            pushSyncMenu(podcasts[0].get("episodes"));
        } else {
            pushPodcastMenu(podcasts);
        }
    }

    // Normalize all feed shapes to [{ "id", "name", "episodes" }].
    // New Pages format has "podcasts"; the old flat "episodes" format and
    // the static fallback catalog are wrapped / grouped into one entry each.
    function normalizePodcasts(responseCode, data) {
        if (responseCode == 200 && data != null) {
            if (data.hasKey("podcasts")) {
                var pods = data["podcasts"];
                for (var p = 0; p < pods.size(); ++p) {
                    tagEpisodes(pods[p].get("episodes"), pods[p].get("name"));
                }
                return pods;
            } else if (data.hasKey("episodes")) {
                var eps = data["episodes"];
                tagEpisodes(eps, "All Ball");
                return [{"id" => "defector", "name" => "All Ball", "episodes" => eps}];
            }
        }
        return groupCatalog(Episodes.CATALOG);
    }

    function tagEpisodes(eps, podcastName) {
        for (var i = 0; i < eps.size(); ++i) {
            if (!eps[i].hasKey("podcast")) {
                eps[i].put("podcast", podcastName);
            }
        }
    }

    // Group the flat static fallback catalog by its "podcast" field.
    function groupCatalog(catalog) {
        var order = [];
        var groups = {};
        for (var i = 0; i < catalog.size(); ++i) {
            var ep = catalog[i];
            var pname = ep.hasKey("podcast") ? ep.get("podcast").toString() : "Podcasts";
            if (!groups.hasKey(pname)) {
                groups[pname] = [];
                order.add(pname);
            }
            groups[pname].add(ep);
        }
        var pods = [];
        for (var j = 0; j < order.size(); ++j) {
            pods.add({"id" => order[j], "name" => order[j], "episodes" => groups[order[j]]});
        }
        return pods;
    }

    function pushPodcastMenu(podcasts) {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.podcastMenuTitle});
        for (var i = 0; i < podcasts.size(); ++i) {
            var count = podcasts[i].get("episodes").size();
            menu.addItem(new WatchUi.MenuItem(
                podcasts[i].get("name").toString(),
                count.toString() + " episodes",
                podcasts[i].get("id"), {}));
        }
        WatchUi.pushView(menu, new ConfigurePodcastMenuDelegate(self, podcasts), WatchUi.SLIDE_IMMEDIATE);
        mMenuShown = true;
    }

    function pushSyncMenu(catalog) {
        var menu = new WatchUi.CheckboxMenu({:title => Rez.Strings.syncMenuTitle});
        var app = Application.getApp();

        var downloaded = app.getProperty(Properties.SONGS);
        if (downloaded == null) {
            downloaded = {};
        }
        // downloaded maps refId -> {CAN_SKIP, ID(episode id)}; build set of episode ids on watch
        var onWatch = {};
        var refIds = downloaded.keys();
        for (var i = 0; i < refIds.size(); ++i) {
            var entry = downloaded[refIds[i]];
            if (entry != null && entry.hasKey(SongInfo.ID)) {
                onWatch[entry[SongInfo.ID]] = true;
            }
        }

        var queued = app.getProperty(Properties.SYNC_LIST);
        if (queued == null) {
            queued = {};
        }

        for (var i = 0; i < catalog.size(); ++i) {
            var ep = catalog[i];
            var epId = ep.get("id");
            var epName = ep.get("name").toString();
            var checked = onWatch.hasKey(epId) || queued.hasKey(epId);
            menu.addItem(new WatchUi.CheckboxMenuItem(epName, null, ep, checked, {}));
        }
        WatchUi.pushView(menu, new ConfigureSyncMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        mMenuShown = true;
    }
}

// First level of the picker: choose a podcast, then its episodes.
// Lives in this file so it can reuse ConfigureSyncView.pushSyncMenu.
class ConfigurePodcastMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var mView;
    private var mPodcasts;

    function initialize(view, podcasts) {
        Menu2InputDelegate.initialize();
        mView = view;
        mPodcasts = podcasts;
    }

    function onSelect(item) {
        var pid = item.getId();
        for (var i = 0; i < mPodcasts.size(); ++i) {
            if (mPodcasts[i].get("id").equals(pid)) {
                mView.pushSyncMenu(mPodcasts[i].get("episodes"));
                return;
            }
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onDone() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
