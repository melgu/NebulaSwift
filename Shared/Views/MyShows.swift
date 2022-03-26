//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct MyShows: View {
	@EnvironmentObject private var api: API
	
	@State private var videos: [Video] = []
	
    var body: some View {
		NavigationView {
			List {
				ForEach(videos) { video in
					NavigationLink {
						VideoView(video: video)
					} label: {
						VideoPreview(video: video)
					}
				}
			}
			.listStyle(.sidebar)
		}
		.task {
			print("Load Videos")
			do {
				videos = try await api.libraryVideos
			} catch {
				print(error)
			}
		}
    }
}

struct VideoPreview: View {
	var video: Video
	
	var body: some View {
		HStack {
			AsyncImage(url: video.assets.thumbnail["1080"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
			}
			.frame(width: 64)
			.cornerRadius(4)
			
			VStack(alignment: .leading) {
				Text(video.title)
					.font(.body)
				Text(video.channelTitle)
					.font(.caption)
			}
			.lineLimit(1)
		}
	}
}

struct VideoView: View {
	var video: Video
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				#if os(macOS)
				HStack {
					Text(video.title)
						.font(.title)
					Spacer()
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
				#endif
				Text(video.description)
				HStack {
					ForEach(video.categorySlugs, id: \.self) { category in
						Text(category)
							.padding(8)
							.background(
								RoundedRectangle(cornerRadius: 4)
									.foregroundColor(.blue)
									.opacity(0.2)
							)
					}
				}
			}
			.padding()
			.frame(maxWidth: .infinity, alignment: .leading)
			.navigationTitle(video.title)
			#if canImport(UIKit)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
			}
			#endif
		}
	}
}

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
    }
}
