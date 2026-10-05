//
//  WatchLater.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 03.06.22.
//

import SwiftUI

struct WatchLater: View {
	@Environment(API.self) private var api
	@Environment(Player.self) private var player
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.watchLaterVideos(page: page)
		})
		.watchLaterList()
		.navigationTitle("Watch Later")
		.statisticsAlert { try await api.watchLaterStatistics() }
	}
}

struct WatchLater_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		WatchLater()
			.environment(api)
			.environment(Player(api: api, storage: Storage(), downloads: DownloadManager(api: api, storage: Storage())))
	}
}
