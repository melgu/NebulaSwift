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
	
	@State private var viewType: ViewType = .videos
	
    var body: some View {
		Group {
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
			player.reset()
		}
    }
}

fileprivate enum ViewType {
	case videos
	case channels
}

struct Browse_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
