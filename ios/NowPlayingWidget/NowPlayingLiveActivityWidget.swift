import ActivityKit
import SwiftUI
import WidgetKit

// Minimal Now Playing-style Live Activity. Tap opens app via widgetURL.
@main
struct NowPlayingWidgetBundle: WidgetBundle {
  var body: some Widget {
    NowPlayingLiveActivityWidget()
  }
}

@available(iOS 16.1, *)
struct NowPlayingLiveActivityWidget: Widget {
  private let openURL = URL(string: "qqmusicpod://nowplaying")

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: NowPlayingAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
          Text(context.state.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .widgetURL(openURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "music.note")
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 1) {
            Text(context.state.title)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.artist)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
        }
      } compactLeading: {
        Image(systemName: "music.note")
      } compactTrailing: {
        Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
      } minimal: {
        Image(systemName: "music.note")
      }
      .widgetURL(openURL)
    }
  }
}