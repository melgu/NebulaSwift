//
//  ContextMenus.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 29.04.22.
//

import SwiftUI

// MARK: Video

extension View {
	func contextMenu(for video: Video) -> some View {
		modifier(VideoContextMenu(video: video))
	}
}

struct VideoContextMenu: ViewModifier {
	let video: Video
	
	@EnvironmentObject private var api: API
	
	@Environment(\.goToChannelEnabled) private var goToChannelEnabled
	@Environment(\.assumeWatchLater) private var assumeWatchLater
	@Environment(\.refresh) private var refresh
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				Text(video.title)
				
				if goToChannelEnabled {
					AsyncNavigationLink(video.channelTitle) {
						try await api.channel(for: video.channelSlug)
					}
				}
				
				Divider()
				
				if let engagement = video.engagement {
					if engagement.watchLater || assumeWatchLater {
						AsyncButton {
							try await api.removeVideoFromWatchLater(video)
							await refresh?()
						} label: {
							Label("Remove from Watch Later", systemImage: "bookmark.slash")
						}
					} else {
						AsyncButton {
							try await api.addVideoToWatchLater(video)
							await refresh?()
						} label: {
							Label("Add to Watch Later", systemImage: "bookmark")
						}
					}
				}
				
				AsyncButton {
					throw Inop.comingSoon
				} label: {
					Label("Download", systemImage: "arrow.down")
				}
				
				if let engagement = video.engagement {
					Divider()
					
					if !engagement.completed {
						AsyncButton {
							try await api.markVideoAsWatched(video)
							await refresh?()
						} label: {
							Label("Mark as watched", systemImage: "checkmark.circle")
						}
					}
					
					if engagement.progress != 0 {
						AsyncButton {
							try await api.clearProgress(for: video)
							await refresh?()
						} label: {
							Label("Clear progress", systemImage: "clock.arrow.circlepath")
						}
					}
				}
				
				Divider()
				
				ShareLink(item: video.shareUrl)
			} preview: {
				LiveVideoPreviewView(video: video)
					.environmentObject(api)
			}
	}
}

// MARK: - Channel

extension View {
	func contextMenu(for channel: Channel) -> some View {
		modifier(ChannelContextMenu(channel: channel))
	}
}

struct ChannelContextMenu: ViewModifier {
	let channel: Channel
	
	@EnvironmentObject private var api: API
	
	@Environment(\.refresh) private var refresh
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				Text(channel.title)
				
				Divider()
				
				if let engagement = channel.engagement {
					if engagement.following {
						AsyncButton {
							try await api.unfollow(channel)
							await refresh?()
						} label: {
							Label("Unfollow", systemImage: "person.fill.badge.minus")
						}
					} else {
						AsyncButton {
							try await api.follow(channel)
							await refresh?()
						} label: {
							Label("Follow", systemImage: "person.fill.badge.plus")
						}
					}
					Divider()
				}
				
				ShareLink(item: channel.shareUrl)
			} preview: {
				AsyncImage(url: channel.assets.banner["960"]?.original) { image in
					image
						.resizable()
				} placeholder: {
					// This image is most likely already cached
					AsyncImage(url: channel.assets.banner["480"]?.original) { image in
						image
							.resizable()
					} placeholder: {
						ProgressView()
							.controlSize(.large)
					}
				}
			}
	}
}

// MARK: - Podcast

extension View {
	func contextMenu(for podcast: Podcast) -> some View {
		modifier(PodcastContextMenu(podcast: podcast))
	}
}

struct PodcastContextMenu: ViewModifier {
	let podcast: Podcast
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				Text(podcast.title)
				
				Divider()
				
				Button("Copy RSS URL") {
					Pasteboard.copy(string: podcast.rssUrl.absoluteString)
				}
				
				Divider()
				
				ShareLink(item: podcast.shareUrl)
			} preview: {
				AsyncImage(url: podcast.assets["square-888"]) { image in
					image
						.resizable()
				} placeholder: {
					// This image is most likely already cached
					AsyncImage(url: podcast.assets["square-400"]) { image in
						image
							.resizable()
							.scaledToFit()
					} placeholder: {
						Color.black
							.aspectRatio(1, contentMode: .fit)
					}
				}
				
			}
	}
}

// MARK: - Hero

extension View {
	func contextMenu(for hero: Hero) -> some View {
		modifier(HeroContextMenu(hero: hero))
	}
}

struct HeroContextMenu: ViewModifier {
	let hero: Hero
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				Text(hero.title)
				
				Divider()
				
				ShareLink(item: hero.url)
			} preview: {
				// This image is most likely already cached
				AsyncImage(url: hero.assets.mobileHero.original) { image in
					image
						.resizable()
				} placeholder: {
					Color.black
						.aspectRatio(1, contentMode: .fit)
				}
			}
	}
}

struct ContextMenus_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
