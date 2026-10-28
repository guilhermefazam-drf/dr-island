import Testing
import Foundation
@testable import DrIslandCore

@Suite struct NowPlayingTests {
    @Test func parsesSpotifyOutput() {
        let np = NowPlaying.parse("Song\tArtist\tplaying\t42\t200\thttps://i.scdn.co/image/abc\n", player: .spotify)
        #expect(np?.title == "Song")
        #expect(np?.isPlaying == true)
        #expect(np?.artworkURL == URL(string: "https://i.scdn.co/image/abc"))
        #expect(np?.position == 42)
        #expect(np?.duration == 200)
        #expect(np?.sourceBundleID == "com.spotify.client")
    }

    @Test func pausedAppleMusicHasNoArtwork() {
        let np = NowPlaying.parse("Song\tArtist\tpaused\t10\t180", player: .appleMusic)
        #expect(np?.isPlaying == false)
        #expect(np?.artworkURL == nil)
    }

    @Test func stoppedOrBadOutputIsNil() {
        #expect(NowPlaying.parse(nil, player: .spotify) == nil)
        #expect(NowPlaying.parse("", player: .spotify) == nil)
        #expect(NowPlaying.parse("only one field", player: .spotify) == nil)
    }

    @Test func nonHTTPSArtworkIsIgnored() {
        #expect(NowPlaying.parse("S\tA\tplaying\t1\t2\thttp://x/y.png", player: .spotify)?.artworkURL == nil)
    }

    @Test func scriptsTargetTheRightApp() {
        #expect(MusicPlayer.spotify.infoScript.contains("com.spotify.client"))
        #expect(MusicPlayer.spotify.infoScript.contains("artwork url"))
        #expect(!MusicPlayer.appleMusic.infoScript.contains("artwork"))
        #expect(MusicPlayer.appleMusic.commandScript("playpause") == #"tell application id "com.apple.Music" to playpause"#)
    }
}

@Suite struct SystemNowPlayingTests {
    @Test func parsesHelperOutput() {
        let json = Data(#"{"title":"Vídeo","artist":"Canal","rate":1,"playing":1,"artwork":"aGk="}"#.utf8)
        let np = NowPlaying.parseSystem(json)
        #expect(np?.player == .system)
        #expect(np?.title == "Vídeo")
        #expect(np?.isPlaying == true)
        #expect(np?.artworkData == Data("hi".utf8))
    }

    @Test func pausedAndEmptyCases() {
        #expect(NowPlaying.parseSystem(Data(#"{"title":"T","artist":null,"rate":0,"playing":0}"#.utf8))?.isPlaying == false)
        #expect(NowPlaying.parseSystem(Data(#"{"title":"T","rate":1}"#.utf8))?.isPlaying == true)
        #expect(NowPlaying.parseSystem(Data("{}".utf8)) == nil)
        #expect(NowPlaying.parseSystem(nil) == nil)
    }
}

@Suite struct PlaybackPositionTests {
    @Test func positionAdvancesWhilePlayingOnly() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let playing = NowPlaying(player: .spotify, title: "S", artist: "A", isPlaying: true, artworkURL: nil, position: 10, duration: 100, asOf: t0)
        #expect(playing.currentPosition(now: t0.addingTimeInterval(5)) == 15)
        #expect(playing.currentPosition(now: t0.addingTimeInterval(500)) == 100)   // never past the end
        let paused = NowPlaying(player: .spotify, title: "S", artist: "A", isPlaying: false, artworkURL: nil, position: 10, duration: 100, asOf: t0)
        #expect(paused.currentPosition(now: t0.addingTimeInterval(5)) == 10)
        #expect(NowPlaying(player: .spotify, title: "S", artist: "A", isPlaying: true, artworkURL: nil).currentPosition() == nil)
    }

    @Test func systemPositionUsesTheTimestamp() {
        let now = Date(timeIntervalSince1970: 2000)
        let json = Data(#"{"title":"T","playing":1,"elapsed":10,"duration":100,"timestamp":1990,"bundle":"com.brave.Browser"}"#.utf8)
        let np = NowPlaying.parseSystem(json, now: now)
        #expect(np?.position == 20)   // 10 s at the timestamp + 10 s since
        #expect(np?.duration == 100)
        #expect(np?.sourceBundleID == "com.brave.Browser")
        #expect(NowPlaying.parseSystem(Data(#"{"title":"T","playing":1,"elapsed":10,"duration":0}"#.utf8))?.duration == nil)
    }
}
