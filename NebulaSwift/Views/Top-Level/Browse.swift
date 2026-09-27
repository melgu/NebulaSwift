//
//  Browse.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Browse: View {
	@Environment(API.self) private var api
	@Environment(Player.self) private var player
	
	@State private var viewType: ContentType = .videos
	@State private var categories: [Category] = []
	@State private var loadingCategories: Task<Void, Never>?
	
	@Environment(\.handleError) private var handleError
	
	var body: some View {
		VStack {
			ScrollView(.horizontal) {
				HStack {
					ForEach(categories) { category in
						CategoryPreview(category: category)
					}
				}
				.padding()
			}
			.navigationDestination(for: Category.self) { category in
				CategoryPage(category: category, initialViewType: viewType)
			}
			switch viewType {
			case .videos:
				AutoVideoGrid(fetch: { page in
					try await api.allVideos(page: page)
				})
			case .channels:
				AutoChannelGrid(fetch: { page in
					try await api.allChannels(page: page)
				})
			}
		}
		.navigationTitle("Browse")
		.toolbar {
			switch viewType {
			case .videos:
				Button("Switch to Channels") {
					viewType = .channels
				}
			case .channels:
				Button("Switch to Videos") {
					viewType = .videos
				}
			}
		}
		.onAppear {
			// Pushing this view cancels a `.task` mid-flight without ever starting it again, which
			// leaves the category row empty on iPhone, so the load outlives the view's appearance instead.
			guard categories.isEmpty, loadingCategories == nil else { return }
			loadingCategories = Task {
				defer { loadingCategories = nil }
				do {
					categories = try await api.allCategories(page: 1, pageSize: 100)
				} catch {
					handleError(error)
				}
			}
		}
	}
}

struct Browse_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
