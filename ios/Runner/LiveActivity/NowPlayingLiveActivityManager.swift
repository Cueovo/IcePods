import ActivityKit
import Foundation

enum NowPlayingLiveActivityManager {
  static func upsert(title: String, artist: String, isPlaying: Bool, songId: String) {
    guard #available(iOS 16.1, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let state = NowPlayingAttributes.ContentState(
      title: title.isEmpty ? "Ambient Player" : title,
      artist: artist.isEmpty ? " " : artist,
      isPlaying: isPlaying
    )
    let attributes = NowPlayingAttributes(songId: songId.isEmpty ? "unknown" : songId)

    Task {
      if let existing = Activity<NowPlayingAttributes>.activities.first {
        await existing.update(using: state)
        return
      }
      do {
        _ = try Activity.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      } catch {
        NSLog("LiveActivity request failed: \(error.localizedDescription)")
      }
    }
  }

  static func endAll() {
    guard #available(iOS 16.1, *) else { return }
    Task {
      for activity in Activity<NowPlayingAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }
}