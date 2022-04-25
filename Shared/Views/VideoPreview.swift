//
//  VideoPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

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

struct VideoPreview: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	
	@Environment(\.goToChannelEnabled) var goToChannelEnabled
	
	@State private var channelInNavigation: Channel?
	@State private var shareUrl: [Any]?
	
	var body: some View {
		NavigationLink {
			VideoPage(video: video)
		} label: {
			VideoPreviewView(video: video)
		}
		.buttonStyle(.plain)
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
				shareUrl = [video.shareUrl]
			} label: {
				Label("Share", systemImage: "square.and.arrow.up")
			}
		}
		.navigation(item: $channelInNavigation) { channel in
			ChannelPage(channel: channel)
		}
		.shareSheet(items: $shareUrl)
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

struct VideoPreviewView: View {
	let video: Video
	
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
			Text(video.channelTitle)
				.font(.caption)
		}
		.lineLimit(2)
		.background(Color.primary.colorInvert())
	}
}

struct VideoPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
