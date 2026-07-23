import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NowPlayingWidgetBundle: WidgetBundle {
  var body: some Widget {
    NowPlayingLiveActivityWidget()
  }
}

@available(iOS 16.1, *)
struct NowPlayingLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: NowPlayingAttributes.self) { context in
      lockScreenView(context: context)
        .widgetURL(URL(string: "qqmusicpod://nowplaying"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "music.note")
            .font(.title2)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.state.title)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.artist)
              .font(.caption)
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("轻触打开 Ambient Player")
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
      } compactLeading: {
        Image(systemName: "music.note")
      } compactTrailing: {
        Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
      } minimal: {
        Image(systemName: "music.note")
      }
      .widgetURL(URL(string: "qqmusicpod://nowplaying"))
    }
  }

  @ViewBuilder
  private func lockScreenView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color.white.opacity(0.15))
          .frame(width: 44, height: 44)
        Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(context.state.title)
          .font(.headline)
          .lineLimit(1)
        Text(context.state.artist)
          .font(.subheadline)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      Image(systemName: "arrow.up.forward.app")
    }
    .padding(14)
    .activityBackgroundTint(Color.black.opacity(0.55))
    .activitySystemActionForegroundColor(.white)
  }
}