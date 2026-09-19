using Toybox.Application;
using Toybox.Communications;
using Toybox.WatchUi;

class ConfigureSyncMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var mSyncList;
    private var mDeleteList;

    function initialize() {
        Menu2InputDelegate.initialize();
        mSyncList = [];
        mDeleteList = [];
    }

    function onSelect(item) {
        var cb = item as WatchUi.CheckboxMenuItem;
        var id = cb.getId();
        if (cb.isChecked()) {
            if (mSyncList.indexOf(id) == -1) {
                mSyncList.add(id);
            }
            var di = mDeleteList.indexOf(id);
            if (di != -1) {
                mDeleteList.remove(di);
            }
        } else {
            var si = mSyncList.indexOf(id);
            if (si != -1) {
                mSyncList.remove(si);
            }
            if (mDeleteList.indexOf(id) == -1) {
                mDeleteList.add(id);
            }
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onDone() {
        var app = Application.getApp();
        var songs = app.getProperty(Properties.SONGS);
        if (songs == null) {
            songs = {};
        }
        var syncInfo = app.getProperty(Properties.SYNC_LIST);
        if (syncInfo == null) {
            syncInfo = {};
        }
        for (var i = 0; i < mSyncList.size(); ++i) {
            var ep = mSyncList[i];
            if (getRefId(ep["id"], songs) == null && !syncInfo.hasKey(ep["id"])) {
                syncInfo[ep["id"]] = {
                    SongInfo.URL => ep["url"],
                    SongInfo.CAN_SKIP => ep["canSkip"],
                    SongInfo.TYPE => ep["type"]
                };
            }
        }
        app.setProperty(Properties.SYNC_LIST, syncInfo);

        var deleteInfo = app.getProperty(Properties.DELETE_LIST);
        if (deleteInfo == null) {
            deleteInfo = [];
        }
        for (var i = 0; i < mDeleteList.size(); ++i) {
            var refId = getRefId(mDeleteList[i]["id"], songs);
            if (refId != null) {
                deleteInfo.add(refId);
            }
        }
        app.setProperty(Properties.DELETE_LIST, deleteInfo);

        // Standard flow: exit and let the system start sync (via the
        // simulator's Settings > Media Mode > Sync, or the on-device
        // prompt). Communications.startSync() is a no-op in the simulator
        // but on-device it prompts the Wi-Fi media sync — without it the
        // app loops on the picker forever (SYNC_LIST saved, SONGS empty).
        Communications.startSync();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    // episode id -> downloaded ContentRef id
    function getRefId(episodeId, songs) {
        var keys = songs.keys();
        for (var i = 0; i < keys.size(); ++i) {
            var e = songs[keys[i]];
            if (e != null && e.hasKey(SongInfo.ID) && e[SongInfo.ID].equals(episodeId)) {
                return keys[i];
            }
        }
        return null;
    }
}
