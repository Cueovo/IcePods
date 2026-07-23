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

    Task { @MainActor in
      if let existing = Activity<NowPlayingAttributes>.activities.first {
        if #available(iOS 16.2, *) {
          let content = ActivityContent(state: state, staleDate: nil)
          await existing.update(content)
        } else {
          await existing.update(using: state)
        }
        return
      }

      do {
        if #available(iOS 16.2, *) {
          let content = ActivityContent(state: state, staleDate: nil)
          _ = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
        } else {
          _ = try Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
          )
        }
      } catch {
        NSLog("NowPlayingLiveActivity request failed: \(error.localizedDescription)")
      }
    }
  }

  static func endAll() {
    guard #available(iOS 16.1, *) else { return }
    Task { @MainActor in
      for activity in Activity<NowPlayingAttributes>.activities {
        if #available(iOS 16.2, *) {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }
  }
}