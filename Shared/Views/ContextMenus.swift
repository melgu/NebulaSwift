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
	
	@Environment(\.goToChannelEnabled) var goToChannelEnabled
	@Environment(\.refresh) private var refresh
	
	@State private var channelInNavigation: Channel?
	@State private var shareURL: [Any]?
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				if goToChannelEnabled {
					Button(video.channelTitle) {
						showChannel(slug: video.channelSlug)
					}
					Divider()
				}
				Button("Watch later") {
					print("Watch later")
				}
				Button("Download") {
					print("Download")
				}
				Divider()
				Button {
					shareURL = [video.shareUrl]
				} label: {
					Label("Share", systemImage: "square.and.arrow.up")
				}
			}
			.navigation(item: $channelInNavigation) { channel in
				ChannelPage(channel: channel)
			}
			.shareSheet(items: $shareURL)
	}
	
	func showChannel(slug: String) {
		Task {
			do {
				channelInNavigation = try await api.channel(for: slug)
			} catch {
				print(error)
			}
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
	
	@State var shareURL: [Any]?
	
	func body(content: Content) -> some View {
		content
			.contextMenu {
				if let engagement = channel.engagement {
					if engagement.following {
						AsyncButton {
							do {
								try await api.unfollow(channel)
								await refresh?()
							} catch {
								print(error)
							}
						} label: {
							Label("Unfollow", systemImage: "person.fill.badge.minus")
						}
					} else {
						AsyncButton {
							do {
								try await api.follow(channel)
								await refresh?()
							} catch {
								print(error)
							}
						} label: {
							Label("Follow", systemImage: "person.fill.badge.plus")
						}
					}
					Divider()
				}
				Button {
					shareURL = [channel.shareUrl]
				} label: {
					Label("Share", systemImage: "square.and.arrow.up")
				}
			}
			.shareSheet(items: $shareURL)
	}
}

struct ContextMenus_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
