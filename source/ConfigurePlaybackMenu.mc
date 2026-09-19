using Toybox.Application;
using Toybox.Media;
using Toybox.WatchUi;

class ConfigurePlaybackMenu extends WatchUi.CheckboxMenu {

    function initialize() {
        CheckboxMenu.initialize({:title => Rez.Strings.playbackMenuTitle});
        // Shortcut back to the downloader: without this, once SONGS is
        // non-empty the user can never reach the episode picker again
        // except via the system's Manage entry (hard to find on-device).
        // Delegate intercepts this id and pushes ConfigureSyncView.
        addItem(new WatchUi.CheckboxMenuItem(
            WatchUi.loadResource(Rez.Strings.downloadMore),
            null, {"downloadMore" => true}, false, {}));
        var app = Application.getApp();
        var current = {};
        var playlist = app.getProperty(Properties.PLAYLIST);
        if (playlist != null) {
            for (var i = 0; i < playlist.size(); ++i) {
                current[playlist[i]] = true;
            }
        }
        var songs = app.getProperty(Properties.SONGS);
        if (songs == null) {
            return;
        }
        var refIds = songs.keys();
        for (var i = 0; i < refIds.size(); ++i) {
            var ref = new Media.ContentRef(refIds[i], Media.CONTENT_TYPE_AUDIO);
            var obj = Media.getCachedContentObj(ref);
            var title = (obj != null) ? obj.getMetadata().title : refIds[i].toString();
            // Prefix with the podcast name once multi-podcast downloads exist.
            // Old SONGS entries (pre-PODCAST) just show the bare title.
            var entry = songs[refIds[i]];
            if (entry != null && entry.hasKey(SongInfo.PODCAST)
                && !entry[SongInfo.PODCAST].equals("")) {
                title = entry[SongInfo.PODCAST].toString() + ": " + title;
            }
            addItem(new WatchUi.CheckboxMenuItem(title, null, refIds[i], current.hasKey(refIds[i]), {}));
        }
    }
}
