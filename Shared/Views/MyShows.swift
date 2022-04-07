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
	@EnvironmentObject private var player: Player
	
	@State private var videos: [Video] = []
	@State private var page = 1
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					NavigationLink {
						VideoView(video: video)
					} label: {
						VideoPreview(video: video)
					}
					.buttonStyle(.plain)
					.contextMenu {
						Button("Watch later") {
							print("Watch later")
						}
						Button("Download") {
							print("Download")
						}
					}
					.task {
						if video == videos.last {
							print("Last video did appear, loading next page")
							do {
								videos += try await api.libraryVideos(page: page + 1)
								page += 1
							} catch {
								print(error)
							}
						}
					}
				}
			}
			.padding()
			.onAppear {
				player.reset()
			}
		}
		.navigationTitle("My Shows")
		.refreshable {
			print("Refresh Videos")
			await refreshVideos()
		}
		.task {
			print("Load Videos")
			await refreshVideos()
		}
		.settingsSheet()
	}
	
	func refreshVideos() async {
		do {
			let newVideos = try await api.libraryVideos(page: 1)
			if newVideos != videos {
				print("Video list changed")
				page = 1
				videos = newVideos
			}
		} catch {
			print(error)
		}
	}
}

struct VideoPreview: View {
	var video: Video
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: video.assets.thumbnail["480"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
					.cornerRadius(8)
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.cornerRadius(4)
			
			Text(video.title)
				.font(.body)
			Text(video.channelTitle)
				.font(.caption)
		}
		.lineLimit(2)
		.background(Color.primary.colorInvert())
	}
}

struct VideoView: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var didAppearOnce = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
					.overlay(CustomVideoPlayer())
					.task {
						guard !didAppearOnce else { return }
						didAppearOnce = true
						print("Load Video Stream Info")
						do {
							try await player.replaceVideo(with: video)
							player.play()
						} catch {
							print(error)
						}
					}
				
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
}

#if canImport(UIKit)
struct CustomVideoPlayer: UIViewControllerRepresentable {
	@EnvironmentObject private var player: Player
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let playerViewController = AVPlayerViewController()
		playerViewController.player = player.player
		return playerViewController
	}
	
	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
#else
struct CustomVideoPlayer: NSViewRepresentable {
	@EnvironmentObject private var player: Player
	
	func makeNSView(context: Context) -> AVPlayerView {
		let playerView = AVPlayerView()
		playerView.player = player.player
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
			.environmentObject(API())
    }
}
