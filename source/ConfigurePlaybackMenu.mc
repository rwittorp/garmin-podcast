using Toybox.Application;
using Toybox.Media;
using Toybox.WatchUi;

class ConfigurePlaybackMenu extends WatchUi.CheckboxMenu {

    function initialize() {
        CheckboxMenu.initialize({:title => Rez.Strings.playbackMenuTitle});
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
            addItem(new WatchUi.CheckboxMenuItem(title, null, refIds[i], current.hasKey(refIds[i]), {}));
        }
    }
}
