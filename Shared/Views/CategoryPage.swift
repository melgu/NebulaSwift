//
//  CategoryPage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.05.22.
//

import SwiftUI

struct CategoryPage: View {
	let category: Category
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var viewType: ContentType
	
	init(category: Category, initialViewType: ContentType) {
		self.category = category
		self.viewType = initialViewType
	}
	
    var body: some View {
		Group {
			switch viewType {
			case .videos:
				AutoVideoGrid { page in
					try await api.videos(for: category, page: page)
				}
			case .channels:
				AutoChannelGrid { page in
					try await api.allChannels(for: category.slug, page: page)
				}
			}
		}
		.onAppear { player.reset() }
		.navigationTitle(category.title)
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
    }
}

struct CategoryPage_Previews: PreviewProvider {
    static var previews: some View {
		Text("No preview")
    }
}
