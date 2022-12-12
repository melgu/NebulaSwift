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
	
	@State private var showStatistics = false
	@State private var statistics: Statistics?
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.watchLaterVideos(page: page)
		})
		.assumeWatchLater()
		.navigationTitle("Watch Later")
		.toolbar {
			AsyncButton {
				guard statistics == nil else {
					showStatistics = true
					return
				}
				let videos = try await api.watchLaterVideos(page: 1, pageSize: 8_192)
				statistics = Statistics(
					count: videos.count,
					duration: .seconds(videos.map(\.duration).reduce(0, +))
				)
				showStatistics = true
			} label: {
				Label("Statistics", systemImage: "info.circle")
			}
			.asyncButtonStyle(.progress(replacesLabel: true))
		}
		.alert("Statistics", isPresented: $showStatistics, presenting: statistics) { _ in
			Button("OK") {}
		} message: { statistics in
			Text("""
			^[\(statistics.count) videos](inflect: true)
			Total duration: \(statistics.duration.formatted()) h
			""")
		}
	}
	
	private struct Statistics {
		let count: Int
		let duration: Duration
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
