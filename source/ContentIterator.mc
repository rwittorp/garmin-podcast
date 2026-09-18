using Toybox.Application;
using Toybox.Math;
using Toybox.Media;

// Iterates over downloaded podcast episodes for the native player.
// Optimized for talk content: skip forward/back enabled, shuffle off by default.
class ContentIterator extends Media.ContentIterator {

    private var mEpisodeIndex;
    private var mPlaylist;
    private var mShuffling;

    function initialize() {
        ContentIterator.initialize();
        mEpisodeIndex = 0;
        mShuffling = false;
        initializePlaylist();
    }

    function getPlaybackProfile() {
        var profile = new PlaybackProfile();
        profile.playbackControls = [
            Media.PLAYBACK_CONTROL_PLAYBACK,
            Media.PLAYBACK_CONTROL_SHUFFLE,
            Media.PLAYBACK_CONTROL_PREVIOUS,
            Media.PLAYBACK_CONTROL_NEXT,
            Media.PLAYBACK_CONTROL_SKIP_FORWARD,
            Media.PLAYBACK_CONTROL_SKIP_BACKWARD,
            Media.PLAYBACK_CONTROL_REPEAT,
        ];
        profile.attemptSkipAfterThumbsDown = false;
        profile.requirePlaybackNotification = false;
        profile.playbackNotificationThreshold = 30;
        profile.skipPreviousThreshold = 4;
        return profile;
    }

    function next() {
        if (mEpisodeIndex < (mPlaylist.size() - 1)) {
            ++mEpisodeIndex;
            return Media.getCachedContentObj(new Media.ContentRef(mPlaylist[mEpisodeIndex], Media.CONTENT_TYPE_AUDIO));
        }
        return null;
    }

    function previous() {
        if (mEpisodeIndex > 0) {
            --mEpisodeIndex;
            return Media.getCachedContentObj(new Media.ContentRef(mPlaylist[mEpisodeIndex], Media.CONTENT_TYPE_AUDIO));
        }
        return null;
    }

    function get() {
        if ((mEpisodeIndex >= 0) && (mEpisodeIndex < mPlaylist.size())) {
            return Media.getCachedContentObj(new Media.ContentRef(mPlaylist[mEpisodeIndex], Media.CONTENT_TYPE_AUDIO));
        }
        return null;
    }

    function peekNext() {
        var i = mEpisodeIndex + 1;
        if (i < mPlaylist.size()) {
            return Media.getCachedContentObj(new Media.ContentRef(mPlaylist[i], Media.CONTENT_TYPE_AUDIO));
        }
        return null;
    }

    function peekPrevious() {
        var i = mEpisodeIndex - 1;
        if (i >= 0) {
            return Media.getCachedContentObj(new Media.ContentRef(mPlaylist[i], Media.CONTENT_TYPE_AUDIO));
        }
        return null;
    }

    function shuffling() {
        return mShuffling;
    }

    function canSkip() {
        var songs = Application.getApp().getProperty(Properties.SONGS);
        if ((songs != null) && (mEpisodeIndex >= 0) && (mEpisodeIndex < mPlaylist.size())) {
            return songs[mPlaylist[mEpisodeIndex]][SongInfo.CAN_SKIP];
        }
        return true;
    }

    function toggleShuffle() {
        if (mShuffling) {
            mShuffling = false;
            initializePlaylist();
        } else {
            shufflePlaylist();
            mShuffling = true;
        }
    }

    function shufflePlaylist() {
        var temp = mPlaylist[0];
        mPlaylist[0] = mPlaylist[mEpisodeIndex];
        mPlaylist[mEpisodeIndex] = temp;
        for (var idx = 1; idx < mPlaylist.size(); ++idx) {
            temp = mPlaylist[idx];
            var n = (Math.rand() % (mPlaylist.size() - idx)) + idx;
            mPlaylist[idx] = mPlaylist[n];
            mPlaylist[n] = temp;
        }
        mEpisodeIndex = 0;
    }

    function initializePlaylist() {
        var temp = Application.getApp().getProperty(Properties.PLAYLIST);
        if (temp == null) {
            var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
            mPlaylist = [];
            if (iter != null) {
                var ep = iter.next();
                while (ep != null) {
                    mPlaylist.add(ep.getId());
                    ep = iter.next();
                }
            }
        } else {
            mPlaylist = new [temp.size()];
            for (var idx = 0; idx < mPlaylist.size(); ++idx) {
                mPlaylist[idx] = temp[idx];
            }
        }
    }
}
