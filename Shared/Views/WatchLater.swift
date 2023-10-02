//
//  WatchLater.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 03.06.22.
//

import SwiftUI

struct WatchLater: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.watchLaterVideos(page: page)
		})
		.assumeWatchLater()
		.navigationTitle("Watch Later")
		.statisticsAlert { try await api.watchLaterVideos(count: .max) }
	}
}

struct WatchLater_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		WatchLater()
			.environmentObject(api)
			.environmentObject(Player(api: api))
	}
}
