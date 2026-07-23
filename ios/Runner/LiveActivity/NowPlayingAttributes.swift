import Foundation
import ActivityKit

/// Shared between Runner and NowPlayingWidget  keep both targets compiling this file.
struct NowPlayingAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var title: String
    var artist: String
    var isPlaying: Bool
  }

  /// Stable id for the track (mid/id). Used only as static attributes.
  var songId: String
}