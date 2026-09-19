using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Media;
using Toybox.PersistedContent;

// Downloads selected episodes over Wi-Fi during system sync
class SyncDelegate extends Communications.SyncDelegate {

    private var mSyncList;
    private var mDeleteList;
    private var mTotal;
    private var mDone;

    function initialize() {
        SyncDelegate.initialize();
        var app = Application.getApp();
        mSyncList = app.getProperty(Properties.SYNC_LIST);
        if (mSyncList == null) {
            mSyncList = {};
        }
        mDeleteList = app.getProperty(Properties.DELETE_LIST);
        if (mDeleteList == null) {
            mDeleteList = [];
        }
        mDone = 0;
    }

    function onStartSync() {
        mTotal = mSyncList.size() + mDeleteList.size();
        deleteEpisodes();
        syncNext();
    }

    function onStopSync() {
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }

    function isSyncNeeded() {
        return ((mSyncList.size() != 0) || (mDeleteList.size() != 0));
    }

    function deleteEpisodes() {
        var app = Application.getApp();
        var songs = app.getProperty(Properties.SONGS);
        if (songs == null) {
            return;
        }
        for (var i = 0; i < mDeleteList.size(); ++i) {
            Media.deleteCachedItem(new Media.ContentRef(mDeleteList[i], Media.CONTENT_TYPE_AUDIO));
            songs.remove(mDeleteList[i]);
            app.setProperty(Properties.SONGS, songs);
            onOneSynced();
        }
        app.deleteProperty(Properties.DELETE_LIST);
    }

    function syncNext() {
        var ids = mSyncList.keys();
        if (ids.size() == 0) {
            Communications.notifySyncComplete(null);
            return;
        }
        var info = mSyncList[ids[0]];
        if (info) {
            var context = {
                SongInfo.CAN_SKIP => info[SongInfo.CAN_SKIP],
                SongInfo.ID => ids[0],
                SongInfo.URL => info[SongInfo.URL],
                SongInfo.PODCAST => info.hasKey(SongInfo.PODCAST) ? info[SongInfo.PODCAST] : ""
            };
            var options = {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
                :mediaEncoding => typeToEncoding(info[SongInfo.TYPE]),
                :context => context
            };
            Communications.makeWebRequest(info[SongInfo.URL], null, options, method(:onDownloaded));
        }
    }

    function typeToEncoding(type) {
        if (type.equals("mp3")) {
            return Media.ENCODING_MP3;
        } else if (type.equals("m4a")) {
            return Media.ENCODING_M4A;
        } else if (type.equals("wav")) {
            return Media.ENCODING_WAV;
        } else if (type.equals("adts")) {
            return Media.ENCODING_ADTS;
        }
        return Media.ENCODING_INVALID;
    }

    function onDownloaded(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null, context as Lang.Dictionary) {
        if (responseCode == 200) {
            var app = Application.getApp();
            mSyncList.remove(context[SongInfo.ID]);
            app.setProperty(Properties.SYNC_LIST, mSyncList);
            var songs = app.getProperty(Properties.SONGS);
            if (songs == null) {
                songs = {};
            }
            context.remove(SongInfo.URL);
            var ref = data as PersistedContent.Iterator;
            songs[ref.getId()] = context;
            app.setProperty(Properties.SONGS, songs);
            onOneSynced();
            syncNext();
        } else {
            Communications.notifySyncComplete("Sync failed: " + responseCode);
        }
    }

    function onOneSynced() {
        ++mDone;
        if (mTotal > 0) {
            var p = (mDone / mTotal.toFloat() * 100).toNumber();
            Communications.notifySyncProgress(p);
        }
    }
}
