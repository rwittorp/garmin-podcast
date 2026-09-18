using Toybox.Application;
using Toybox.Graphics;
using Toybox.Media;
using Toybox.WatchUi;

class ConfigurePlaybackView extends WatchUi.View {

    private var mMenuShown = false;
    private var mMessage = "";

    function initialize() {
        View.initialize();
    }

    function onShow() {
        if (!mMenuShown) {
            var songs = Application.getApp().getProperty(Properties.SONGS);
            if ((songs != null) && (songs.size() != 0)) {
                WatchUi.pushView(new ConfigurePlaybackMenu(), new ConfigurePlaybackMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
            } else {
                // Nothing downloaded yet: jump straight to the episode picker
                // so sync can be queued from here (sync-config is deprecated).
                WatchUi.pushView(new ConfigureSyncView(), null, WatchUi.SLIDE_IMMEDIATE);
            }
            mMenuShown = true;
        } else {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, mMessage,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
