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
        var catalog;
        if (responseCode == 200 && data != null && data.hasKey("episodes")) {
            catalog = data["episodes"];
        } else {
            catalog = Episodes.CATALOG;
        }
        pushSyncMenu(catalog);
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
