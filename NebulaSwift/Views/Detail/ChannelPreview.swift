//
//  ChannelPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import SwiftUI

struct ChannelPreview: View {
	let channel: Channel

	@Environment(Storage.self) private var storage

	/// The drag preview is laid out without a size proposal, so it adopts the cell's width to match the grid.
	@State private var width: CGFloat?

	var body: some View {
		NavigationLink(value: channel) {
			ChannelPreviewView(channel: channel)
				.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
				.draggable(channel.shareUrl) {
					// The drag preview doesn't inherit the environment.
					ChannelPreviewView(channel: channel)
						.environment(storage)
						.frame(width: width)
						.background(Color.systemBackground)
						.cornerRadius(8)
				}
		}
		.buttonStyle(.plain)
		.contextMenu(for: channel)
	}
}

struct ChannelPreviewView: View {
	let channel: Channel
	
	@Environment(Storage.self) private var storage
	
	var body: some View {
		VStack(alignment: .leading) {
			Color.black
				.aspectRatio(16/9, contentMode: .fit)
				.overlay {
					AsyncImage(url: channel.images.wide[480]) { image in
						image
							.resizable()
							.scaledToFit()
					} placeholder: {
						EmptyView()
					}
					.accessibilityHidden(true)
				}
				.cornerRadius(8)
			
			Text(channel.title)
		}
		// Cells of uneven height leave the grid pulled down after a slow pull to refresh.
		.lineLimit(storage.previewTitleLines, reservesSpace: true)
	}
}

struct ChannelPreview_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
