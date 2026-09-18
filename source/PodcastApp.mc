using Toybox.Application;
using Toybox.Media;

class PodcastApp extends Application.AudioContentProviderApp {

    function initialize() {
        var version = getProperty(Properties.APP_VERSION);
        if (version != Versions.current) {
            clearProperties();
            Media.resetContentCache();
            setProperty(Properties.APP_VERSION, Versions.current);
        }
        AudioContentProviderApp.initialize();
    }

    // Called by the system media player to get episodes to play
    function getContentDelegate(args) {
        return new ContentDelegate();
    }

    // Called by the system when Wi-Fi sync starts
    function getSyncDelegate() {
        return new SyncDelegate();
    }

    // UI shown when user picks "what to play" in the music app
    function getPlaybackConfigurationView() {
        return [new ConfigurePlaybackView()];
    }

    // UI shown when user picks "what to download" (Add music & podcasts)
    function getSyncConfigurationView() {
        return [new ConfigureSyncView()];
    }
}
