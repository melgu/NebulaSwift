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
	
	var body: some View {
		NavigationLink {
			VideoPage(video: video)
		} label: {
			VideoPreviewView(video: video)
		}
		.buttonStyle(.plain)
		.contextMenu(for: video)
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
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.overlay(
				Text((Date.now..<Date.now + Double(video.duration)).formatted(.timeDuration))
					.font(.caption)
					.padding(2)
					.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
					.padding(8)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
			)
			.overlay(progressBar)
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
		.background(Color.primary.colorInvert())
	}
	
	@ViewBuilder
	var progressBar: some View {
		if let progress = video.engagement?.progress, progress != 0 {
			ProgressView(value: Double(progress) / Double(video.duration))
				.frame(maxHeight: .infinity, alignment: .bottom)
		}
	}
}

struct VideoPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
