//
//  ChannelPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import SwiftUI

struct ChannelPreview: View {
	let channel: Channel
	
	var body: some View {
		NavigationLink(value: channel) {
			ChannelPreviewView(channel: channel)
				.draggable(channel.shareUrl) {
					ChannelPreviewView(channel: channel)
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
				}
				.cornerRadius(8)
			
			Text(channel.title)
		}
		// Cells of uneven height leave the grid pulled down after a slow pull to refresh.
		.lineLimit(2, reservesSpace: true)
	}
}

struct ChannelPreview_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
