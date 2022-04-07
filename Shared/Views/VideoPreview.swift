//
//  VideoPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoPreview: View {
	var video: Video
	
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
				.font(.body)
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
