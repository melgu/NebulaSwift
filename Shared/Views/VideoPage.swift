//
//  VideoPage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoPage: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var didAppearOnce = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				videoPlayer
				description
			}
			.padding()
			.navigationTitle(video.title)
			#if canImport(UIKit)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					ShareButton(items: [video.shareUrl]) {
						Label("Share", systemImage: "square.and.arrow.up")
					}
				}
			}
			#endif
		}
	}
	
	var videoPlayer: some View {
		Color.black
			.aspectRatio(16/9, contentMode: .fit)
			.overlay(CustomVideoPlayer())
			.task {
				guard !didAppearOnce else { return }
				didAppearOnce = true
				print("Load Video Stream Info")
				do {
					try await player.replaceVideo(with: video)
					player.play()
				} catch {
					print(error)
				}
			}
	}
	
	var description: some View {
		VStack(alignment: .leading) {
			#if os(macOS)
			HStack {
				Text(video.title)
					.font(.title)
				Spacer()
				ShareButton(items: [video.shareUrl]) {
					Label("Share", systemImage: "square.and.arrow.up")
				}
			}
			#endif
			
			Text(video.description)
			
			if let categorySlugs = video.categorySlugs {
				HStack {
					ForEach(categorySlugs, id: \.self) { category in
						categoryPreview(for: category)
					}
				}
			}
		}
	}
	
	func categoryPreview(for slug: String) -> some View {
		AsyncNavigationLink { () -> Category in
			let categories = try await api.allCategories(page: 1, pageSize: 100)
			guard let category = categories.first(where: { $0.slug == slug }) else {
				throw VideoPageError.categoryNotFound
			}
			return category
		} destination: { category in
			AutoVideoGrid { page in
				try await api.allVideos(for: slug, page: page)
			}
			.onAppear { player.reset() }
			.navigationTitle(category.title)
		} label: { status in
			ZStack {
				Text(slug)
					.padding(8)
					.background(
						RoundedRectangle(cornerRadius: 4)
							.foregroundColor(.accentColor)
							.opacity(0.2)
					)
				if case .loading = status {
					ProgressView()
				}
			}
		}
	}
	
	private enum VideoPageError: Error {
		case categoryNotFound
	}
}

struct VideoPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
