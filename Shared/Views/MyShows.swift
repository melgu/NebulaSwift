//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import AVKit

struct MyShows: View {
	@EnvironmentObject private var api: API
	
	@State private var videos: [Video] = []
	@State private var videoSelection: String?
	
    var body: some View {
		NavigationView {
			List {
				ForEach(videos) { video in
					NavigationLink(tag: video.id, selection: $videoSelection) {
						VideoView(video: video, videoSelection: $videoSelection)
					} label: {
						VideoPreview(video: video)
					}
				}
			}
			.listStyle(.sidebar)
			.refreshable {
				print("Refresh Videos")
				do {
					videos = try await api.libraryVideos
				} catch {
					print(error)
				}
			}
		}
		.task {
			print("Load Videos")
			do {
				videos = try await api.libraryVideos
			} catch {
				print(error)
			}
		}
    }
}

struct VideoPreview: View {
	var video: Video
	
	var body: some View {
		HStack {
			AsyncImage(url: video.assets.thumbnail["1080"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.frame(width: 64)
			.cornerRadius(4)
			
			VStack(alignment: .leading) {
				Text(video.title)
					.font(.body)
				Text(video.channelTitle)
					.font(.caption)
			}
			.lineLimit(1)
		}
	}
}

struct VideoView: View {
	let video: Video
	@Binding var videoSelection: String?
	
	@EnvironmentObject private var api: API
	
	@State private var player = AVPlayer(playerItem: nil)
	@State private var task: Task<(), Error>?
	@State private var didAppearOnce = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				Color.black
					.aspectRatio(1.8888888889, contentMode: .fit)
					.overlay(CustomVideoPlayer(player: player))
					.task {
						guard !didAppearOnce else { return }
						didAppearOnce = true
						print("Load Video Stream Info")
						task = Task {
							let stream = try await api.stream(for: video)
							let item = AVPlayerItem(url: stream.manifest)
							try Task.checkCancellation()
							player.replaceCurrentItem(with: item)
							player.play()
						}
						do {
							try await task?.value
						} catch {
							print(error)
						}
					}
					#if canImport(UIKit)
					.onChange(of: videoSelection) { _ in
						videoSelectionChanged()
					}
					#else
					.onDisappear(perform: videoSelectionChanged)
					#endif
				
				#if os(macOS)
				HStack {
					Text(video.title)
						.font(.title)
					Spacer()
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
				#endif
				Text(video.description)
				HStack {
					ForEach(video.categorySlugs, id: \.self) { category in
						Text(category)
							.padding(8)
							.background(
								RoundedRectangle(cornerRadius: 4)
									.foregroundColor(.blue)
									.opacity(0.2)
							)
					}
				}
			}
			.padding()
			.navigationTitle(video.title)
			#if canImport(UIKit)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
			}
			#endif
		}
	}
	
	func videoSelectionChanged() {
		print("Video selection changed")
		task?.cancel()
		if let item = player.currentItem {
			print("Video stopped at \(player.currentTime().seconds)/\(item.duration.seconds)")
		}
		player.replaceCurrentItem(with: nil)
	}
}

#if canImport(UIKit)
struct CustomVideoPlayer: UIViewControllerRepresentable {
	let player: AVPlayer
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let playerViewController = AVPlayerViewController()
		playerViewController.player = player
		return playerViewController
	}
	
	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
#else
struct CustomVideoPlayer: NSViewRepresentable {
	let player: AVPlayer
	
	func makeNSView(context: Context) -> AVPlayerView {
		let playerView = AVPlayerView()
		playerView.player = player
		playerView.showsFullScreenToggleButton = true
		playerView.allowsPictureInPicturePlayback = true
		return playerView
	}
	
	func updateNSView(_ nsView: NSViewType, context: Context) {}
}
#endif

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
    }
}
