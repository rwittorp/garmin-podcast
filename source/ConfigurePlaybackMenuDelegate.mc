using Toybox.Application;
using Toybox.Lang;
using Toybox.Media;
using Toybox.WatchUi;

class ConfigurePlaybackMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var cb = item as WatchUi.CheckboxMenuItem;
        var id = cb.getId();
        // "+ Download more..." shortcut: jump to the episode picker
        // instead of touching the playlist.
        if (id instanceof Lang.Dictionary && id.hasKey("downloadMore")) {
            cb.setChecked(false);
            WatchUi.pushView(new ConfigureSyncView(), null, WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        var app = Application.getApp();
        var playlist = app.getProperty(Properties.PLAYLIST);
        if (playlist == null) {
            playlist = [];
        }
        if (cb.isChecked()) {
            if (playlist.indexOf(id) == -1) {
                playlist.add(id);
            }
        } else {
            var idx = playlist.indexOf(id);
            if (idx != -1) {
                playlist.remove(idx);
            }
        }
        app.setProperty(Properties.PLAYLIST, playlist);
    }

    function onDone() {
        Media.startPlayback(null);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
