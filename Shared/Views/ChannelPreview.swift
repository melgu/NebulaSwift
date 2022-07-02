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
	
	var body: some View {
		NavigationLink(value: channel) {
			ChannelPreviewView(channel: channel)
		}
		.buttonStyle(.plain)
		.contextMenu(for: channel)
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
	}
}

struct ChannelPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
