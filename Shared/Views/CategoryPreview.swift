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
	let target: ContentType
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	init(slug: String, target: ContentType) {
		self.slug = slug
		self.category = nil
		self.target = target
	}
	
	init(category: Category, target: ContentType) {
		self.slug = category.slug
		self.category = category
		self.target = target
	}
	
	var body: some View {
		if let category = category {
			NavigationLink {
				CategoryPage(category: category, initialViewType: target)
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
				CategoryPage(category: category, initialViewType: target)
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
		Group {
			CategoryPreview(slug: "animation", target: .videos)
			CategoryPreview(slug: "animation", target: .channels)
		}
		.environmentObject(api)
		.environmentObject(Player(api: api))
    }
}
