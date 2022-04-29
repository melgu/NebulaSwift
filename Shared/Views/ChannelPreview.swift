//
//  ChannelPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import SwiftUI

struct ChannelPreview: View {
	let channel: Channel
	
	@EnvironmentObject private var api: API
	
	@Environment(\.refresh) private var refresh
	
	@State private var shareUrl: [Any]?
	
	var body: some View {
		NavigationLink {
			ChannelPage(channel: channel)
		} label: {
			ChannelPreviewView(channel: channel)
		}
		.buttonStyle(.plain)
		.contextMenu {
			if let engagement = channel.engagement {
				if engagement.following {
					Button {
						Task {
							do {
								try await api.follow(channel)
								await refresh?()
							} catch {
								print(error)
							}
						}
					} label: {
						Label("Unfollow", systemImage: "person.fill.badge.minus")
					}
				} else {
					Button {
						Task {
							do {
								try await api.follow(channel)
								await refresh?()
							} catch {
								print(error)
							}
						}
					} label: {
						Label("Follow", systemImage: "person.fill.badge.plus")
					}
				}
				Divider()
			}
			Button {
				shareUrl = [channel.shareUrl]
			} label: {
				Label("Share", systemImage: "square.and.arrow.up")
			}
		}
		.shareSheet(items: $shareUrl)
	}
}

struct ChannelPreviewView: View {
	let channel: Channel
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: channel.assets.banner["480"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
					.cornerRadius(8)
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.cornerRadius(4)
			
			Text(channel.title)
		}
		.lineLimit(2)
		.background(Color.primary.colorInvert())
	}
}

struct ChannelPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
