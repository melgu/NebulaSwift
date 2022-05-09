//
//  CategoryPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 09.05.22.
//

import SwiftUI

struct CategoryPreview: View {
	let slug: String
	let category: Category?
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	init(slug: String) {
		self.slug = slug
		self.category = nil
	}
	
	init(category: Category) {
		self.slug = category.slug
		self.category = category
	}
	
	var body: some View {
		if let category = category {
			NavigationLink {
				destination(category: category)
			} label: {
				label
			}
		} else {
			AsyncNavigationLink { () -> Category in
				let categories = try await api.allCategories(page: 1, pageSize: 100)
				guard let category = categories.first(where: { $0.slug == slug }) else {
					throw CategoryPreviewError.categoryNotFound
				}
				return category
			} destination: { category in
				destination(category: category)
			} label: { status in
				ZStack {
					label
					if case .loading = status {
						ProgressView()
					}
				}
			}
		}
	}
	
	func destination(category: Category) -> some View {
		AutoVideoGrid { page in
			try await api.allVideos(for: slug, page: page)
		}
		.onAppear { player.reset() }
		.navigationTitle(category.title)
	}
	
	var label: some View {
		Text(category?.title ?? slug)
			.padding(8)
			.background(
				RoundedRectangle(cornerRadius: 4)
					.foregroundColor(.accentColor)
					.opacity(0.2)
			)
	}
	
	private enum CategoryPreviewError: Error {
		case categoryNotFound
	}
}

struct CategoryPreview_Previews: PreviewProvider {
	private static let api = API()
	
    static var previews: some View {
		CategoryPreview(slug: "animation")
			.environmentObject(api)
			.environmentObject(Player(api: api))
    }
}
