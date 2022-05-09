//
//  Browse.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Browse: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var viewType: ContentType = .videos
	@State private var categories: [Category] = []
	
    var body: some View {
		Group {
			switch viewType {
			case .videos:
				videoGrid
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
		.task {
			player.reset()
			do {
				categories = try await api.allCategories(page: 1, pageSize: 100)
			} catch {
				print(error)
			}
		}
    }
	
	var videoGrid: some View {
		VStack {
			ScrollView(.horizontal) {
				HStack {
					ForEach(categories) { category in
						CategoryPreview(category: category)
					}
				}
				.padding()
			}
			AutoVideoGrid(fetch: { page in
				try await api.allVideos(page: page)
			})
		}
	}
}

struct Browse_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
