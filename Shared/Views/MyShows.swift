//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct MyShows: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var viewType: ContentType = .videos
	
	var body: some View {
		Group {
			switch viewType {
			case .videos:
				AutoVideoGrid(fetch: { page in
					try await api.libraryVideos(page: page)
				})
			case .channels:
				AutoChannelGrid(fetch: { page in
					try await api.libraryChannels(page: page)
				})
			}
		}
		.navigationTitle("My Shows")
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

struct MyShows_Previews: PreviewProvider {
	static var previews: some View {
		MyShows()
			.environmentObject(API())
	}
}
