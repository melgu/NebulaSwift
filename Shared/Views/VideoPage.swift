//
//  VideoPage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoPage: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@Environment(\.refresh) private var refresh
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openItem) private var openItem
	
	@State private var watchLater: Bool?
	
	init(video: Video) {
		self.video = video
		self._watchLater = State(initialValue: video.engagement?.watchLater)
	}
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading) {
					videoPlayer
					description
				}
				.padding()
			}
			.navigationTitle(video.title)
			.navigationBarCloseButton {
				player.reset()
			}
			#if canImport(UIKit)
			.toolbar {
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					if let watchLater = watchLater {
						if watchLater {
							AsyncButton {
								try await api.removeVideoFromWatchLater(video)
								self.watchLater = false
								await refresh?()
							} label: {
								Label("Remove from Watch Later", systemImage: "bookmark.fill")
							}
						} else {
							AsyncButton {
								try await api.addVideoToWatchLater(video)
								self.watchLater = false
								await refresh?()
							} label: {
								Label("Add to Watch Later", systemImage: "bookmark")
							}
						}
					}
					ShareLink(item: video.shareUrl)
				}
			}
			#endif
		}
		.userActivity("de.melgu.NebulaSwift.video") { activity in
			activity.title = video.title
			try! activity.setTypedPayload(video)
			activity.webpageURL = video.shareUrl
		}
	}
	
	private var videoPlayer: some View {
		Color.black
			.aspectRatio(16/9, contentMode: .fit)
			.overlay(CustomVideoPlayer())
			.task {
				print("Load Video Stream Info")
				try await player.replaceVideo(with: video)
				player.play()
			}
	}
	
	private var description: some View {
		VStack(alignment: .leading) {
			#if os(macOS)
			HStack {
				Text(video.title)
					.font(.title)
				Spacer()
				ShareLink(item: video.shareUrl)
			}
			#endif
			
			channelLink
			
			Divider()
			
			if let attributedDescription = attributedDescription {
				Text(attributedDescription)
			} else {
				Text(video.description)
			}
			
			HStack {
				ForEach(video.categorySlugs, id: \.self) { slug in
					CategoryPreview(slug: slug)
				}
			}
			.navigationDestination(for: Category.self) { category in
				CategoryPage(category: category, initialViewType: .videos)
			}
		}
	}
	
	private var channelLink: some View {
		AsyncButton {
			dismiss()
			player.reset()
			let channel = try await api.channel(for: video.channelSlug)
			openItem(channel)
		} label: {
			HStack(spacing: 16) {
				AsyncImage(url: video.assets.channelAvatar["128"]?.original) { image in
					image
						.resizable()
						.scaledToFit()
						.clipShape(Circle())
				} placeholder: {
					Color.clear
						.aspectRatio(1, contentMode: .fit)
				}
				.frame(width: 64, height: 64)
				
				Text(video.channelTitle)
					.font(.headline)
			}
		}
		.buttonStyle(.plain)
		.asyncButtonStyle(.progress(replacesLabel: false))
	}
	
	private var attributedDescription: AttributedString? {
		try? AttributedString(
			markdown: video.description,
			options: .init(
				allowsExtendedAttributes: false,
				interpretedSyntax: .inlineOnlyPreservingWhitespace,
				failurePolicy: .throwError,
				languageCode: nil
			)
		)
	}
}

struct VideoPage_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
