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
			_ = await UIApplication.shared.open(url)
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
	
	@Environment(Storage.self) private var storage
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: podcast.assets["square-400"]) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(1, contentMode: .fit)
			}
			.cornerRadius(8)
			.accessibilityHidden(true)
			
			Text(podcast.title)
		}
		// Cells of uneven height leave the grid pulled down after a slow pull to refresh.
		.lineLimit(storage.previewTitleLines, reservesSpace: true)
	}
}

struct PodcastPreview_Previews: PreviewProvider {
	static var previews: some View {
		Text("No Preview")
	}
}
