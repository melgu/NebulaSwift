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

extension EnvironmentValues {
	@Entry var goToChannelEnabled: Bool = true
}

extension View {
	func disableGoToChannel() -> some View {
		environment(\.goToChannelEnabled, false)
	}
}

extension EnvironmentValues {
	/// Whether the videos are shown as part of the Watch Later list, so removing one takes it out of the list.
	@Entry var isWatchLaterList: Bool = false
}

extension View {
	func watchLaterList() -> some View {
		environment(\.isWatchLaterList, true)
	}
}

// MARK: Video Preview

struct VideoPreview: View {
	let video: Video
	
	@Environment(\.openItem) private var openItem
	@Environment(Storage.self) private var storage

	/// The drag preview is laid out without a size proposal, so it adopts the cell's width to match the grid.
	@State private var width: CGFloat?

	var body: some View {
		Button {
			openItem(video)
		} label: {
			VideoPreviewView(video: video)
				.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
				.draggable(video.shareUrl) {
					// The drag preview doesn't inherit the environment.
					VideoPreviewView(video: video)
						.environment(storage)
						.frame(width: width)
						.background(Color.systemBackground)
						.cornerRadius(8)
				}
		}
		.buttonStyle(.plain)
		.contextMenu(for: video)
	}
}

struct VideoPreviewView: View {
	let video: Video
	
	@Environment(Storage.self) private var storage
	
	init(video: Video) {
		self.video = video
	}
	
	var body: some View {
		VStack(alignment: .leading) {
			Color.black
				.aspectRatio(16/9, contentMode: .fit)
				.overlay {
					AsyncImage(url: video.images.thumbnail[480]) { image in
						image
							.resizable()
							.scaledToFill()
					} placeholder: {
						EmptyView()
					}
				}
				.overlay(informationOverlay)
				.cornerRadius(8)
			
			HStack(alignment: .top) {
				AsyncImage(url: video.images.channelAvatar[64]) { image in
					image
						.resizable()
						.scaledToFit()
						.clipShape(Circle())
				} placeholder: {
					Color.clear
						.aspectRatio(1, contentMode: .fit)
				}
				.frame(width: 32, height: 32)
				// Cells of uneven height leave the grid pulled down after a slow pull to refresh.
				VStack(alignment: .leading) {
					Text(video.title)
						.lineLimit(storage.previewTitleLines, reservesSpace: true)
					Text(video.channelTitle)
						.font(.caption)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
			}
		}
		.lineLimit(storage.previewTitleLines)
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
					Text((Date.now ..< Date.now + Double(video.duration)).formatted(.timeDuration))
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

struct VideoPreviewImage: View {
	let video: Video
	
	var body: some View {
		AsyncImage(url: video.images.thumbnail[960]) { image in
			image
				.resizable()
		} placeholder: {
			// This image is most likely already cached
			AsyncImage(url: video.images.thumbnail[480]) { image in
				image
					.resizable()
			} placeholder: {
				ProgressView()
					.controlSize(.large)
			}
		}
	}
}

struct LiveVideoPreviewView: View {
	let video: Video
	
	@Environment(API.self) private var api
	@Environment(Player.self) private var mainPlayer
	@Environment(Storage.self) private var storage
	
	@State private var player = AVPlayer()
	@State private var isMuted = false
	@State private var loadingTask: Task<Void, Error>?
	@State private var prerollTask: Task<Void, Error>?
	@State private var readyToPlay = false
	@State private var cancellable: AnyCancellable?
	
	var body: some View {
		VideoPreviewImage(video: video)
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
				isMuted = !storage.videoPreviewWithSound
				player.isMuted = isMuted
				// The automatic selection turns subtitles off again unless the device itself is muted
				player.appliesMediaSelectionCriteriaAutomatically = !isMuted
				mainPlayer.beginPreview(muted: isMuted)
				
				cancellable = player.publisher(for: \.status)
					.print("Video Preview")
					.handleEvents(receiveCompletion: { _ in
						player.replaceCurrentItem(with: nil)
					}, receiveCancel: {
						player.replaceCurrentItem(with: nil)
					})
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
										let item = AVPlayerItem(url: try api.manifestURL(for: video))
					player.replaceCurrentItem(with: item)
					if let progress = video.engagement?.progress {
						await player.seek(to: CMTime(seconds: Double(progress), preferredTimescale: 1))
					}
					if isMuted {
						await showSubtitles(for: item)
					}
				}
				try await loadingTask?.value
			}
			.onDisappear {
				loadingTask?.cancel()
				prerollTask?.cancel()
				cancellable?.cancel()
				player.pause()
				mainPlayer.endPreview(muted: isMuted)
			}
	}

	/// Picks subtitles in the video's original language, falling back to the first full subtitle track.
	private func showSubtitles(for item: AVPlayerItem) async {
		guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
		let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, withoutMediaCharacteristics: [.containsOnlyForcedSubtitles])
		var original: [AVMediaSelectionOption] = []
		if let language = await originalLanguage(of: item) {
			original = AVMediaSelectionGroup.mediaSelectionOptions(from: options, filteredAndSortedAccordingToPreferredLanguages: [language])
		}
		guard let option = original.first ?? options.first else { return }
		item.select(option, in: group)
	}

	/// The language of the audio track marked as original, or else of the default audio track.
	private func originalLanguage(of item: AVPlayerItem) async -> String? {
		guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return nil }
		let original = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, withMediaCharacteristics: [.isOriginalContent]).first
		return (original ?? group.defaultOption ?? group.options.first)?.extendedLanguageTag
	}
}

struct VideoPreview_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
