//
//  VideoPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI
import Combine
import AVKit

// MARK: - Environment

private struct GoToChannelEnabledKey: EnvironmentKey {
	static let defaultValue = true
}

extension EnvironmentValues {
	var goToChannelEnabled: Bool {
		get { self[GoToChannelEnabledKey.self] }
		set { self[GoToChannelEnabledKey.self] = newValue }
	}
}

extension View {
	func disableGoToChannel() -> some View {
		environment(\.goToChannelEnabled, false)
	}
}

// MARK: Video Preview

struct VideoPreview: View {
	let video: Video
	
	var body: some View {
		NavigationLink(value: video) {
			VideoPreviewView(video: video)
		}
		.buttonStyle(.plain)
		.contextMenu(for: video)
	}
}

struct VideoPreviewView: View {
	let video: Video
	
	init(video: Video) {
		self.video = video
	}
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: video.assets.thumbnail["480"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.overlay(informationOverlay)
			.cornerRadius(8)
			
			HStack(alignment: .top) {
				AsyncImage(url: video.assets.channelAvatar["64"]?.original) { image in
					image
						.resizable()
						.scaledToFit()
						.clipShape(Circle())
				} placeholder: {
					Color.clear
						.aspectRatio(1, contentMode: .fit)
				}
				.frame(width: 32, height: 32)
				VStack(alignment: .leading) {
					Text(video.title)
					Text(video.channelTitle)
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		.lineLimit(2)
	}
	
	private var informationOverlay: some View {
		VStack(alignment: .trailing) {
			if video.engagement?.watchLater == true {
				Image(systemName: "bookmark.fill")
					.padding(2)
					.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
			}
			Spacer()
			HStack {
				if let progress = video.engagement?.progress, progress != 0 {
					ProgressView(value: Double(progress), total: Double(video.duration))
						.progressViewStyle(.watchTime)
				}
				
				HStack(spacing: 2) {
					if video.attributes.contains(.isNebulaPlus) {
						Image(systemName: "plus")
							.foregroundColor(.accentColor)
					}
					Text((Date.now..<Date.now + Double(video.duration)).formatted(.timeDuration))
				}
				.font(.caption)
				.padding(2)
				.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
			}
		}
		.padding(8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
	}
}

struct LiveVideoPreviewView: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	
	@State private var player = AVPlayer()
	@State private var loadingTask: Task<Void, Error>?
	@State private var prerollTask: Task<Void, Error>?
	@State private var readyToPlay = false
	@State private var cancellable: AnyCancellable?
	
	var body: some View {
		AsyncImage(url: video.assets.thumbnail["960"]?.original) { image in
			image
				.resizable()
		} placeholder: {
			// This image is most likely already cached
			AsyncImage(url: video.assets.thumbnail["480"]?.original) { image in
				image
					.resizable()
			} placeholder: {
				ProgressView()
					.controlSize(.large)
			}
		}
		.overlay {
			if readyToPlay {
				VideoPlayer(player: player)
					.transition(.opacity)
			} else {
				ProgressView()
					.controlSize(.large)
			}
		}
		.task {
			cancellable = player.publisher(for: \.status)
				.print("Video Preview")
				.filter { $0 == .readyToPlay }
				.sink { _ in
					prerollTask = Task {
						await player.preroll(atRate: 1)
						try Task.checkCancellation()
						withAnimation { self.readyToPlay = true }
						player.play()
					}
					Task { try await prerollTask?.value }
				}
			
			loadingTask = Task {
				let stream = try await api.stream(for: video)
				let item = AVPlayerItem(url: stream.manifest)
				player.replaceCurrentItem(with: item)
				if let progress = video.engagement?.progress {
					await player.seek(to: CMTime(seconds: Double(progress), preferredTimescale: 1))
				}
			}
			try await loadingTask?.value
		}
		.onDisappear {
			loadingTask?.cancel()
			prerollTask?.cancel()
			cancellable = nil
			player.replaceCurrentItem(with: nil)
		}
	}
}

struct VideoPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
