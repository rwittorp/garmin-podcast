using Toybox.Application;
using Toybox.Media;

// Hands cached episodes to the native media player
class ContentDelegate extends Media.ContentDelegate {

    private var mIterator;

    function initialize() {
        ContentDelegate.initialize();
        resetContentIterator();
    }

    function getContentIterator() {
        return mIterator;
    }

    function resetContentIterator() {
        mIterator = new ContentIterator();
        return mIterator;
    }

    function onSong(refId, songEvent, playbackPosition) {
        // Playback events (start / skip / complete / pause / resume).
        // Kept as a no-op: reporting back to a server happens in V3.
    }

    function onShuffle() {
        mIterator.toggleShuffle();
    }
}
