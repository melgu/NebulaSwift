//
//  PodcastPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import SwiftUI

struct PodcastPreview: View {
	let podcast: Podcast
	
	var body: some View {
		AsyncButton {
			let url = podcast.apple ?? podcast.shareUrl
			#if os(iOS)
			await UIApplication.shared.open(url)
			#else
			NSWorkspace.shared.open(url)
			#endif
		} label: {
			PodcastPreviewView(podcast: podcast)
		}
		.buttonStyle(.plain)
		.contextMenu(for: podcast)
	}
}

struct PodcastPreviewView: View {
	let podcast: Podcast
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: podcast.assets["square-400"]) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.cornerRadius(8)
			
			Text(podcast.title)
		}
		.lineLimit(2)
	}
}

struct PodcastPreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("No Preview")
    }
}
