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
	@Environment(\.refresh) private var refresh
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				if goToChannelEnabled {
					AsyncNavigationLink(video.channelTitle) {
						try await api.channel(for: video.channelSlug)
					}
					Divider()
				}
				if let engagement = video.engagement {
					if engagement.watchLater {
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
				Button {
					print("Download")
				} label: {
					Label("Download", systemImage: "arrow.down")
				}
				Divider()
				ShareLink(item: video.shareUrl)
			} preview: {
				LiveVideoPreviewView(video: video)
					.environmentObject(api)
					.padding(.vertical)
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
				ChannelPreviewView(channel: channel)
					.padding(.vertical)
			}
	}
}

struct ContextMenus_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
