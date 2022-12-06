//
//  VideoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoGrid: View {
	let videos: [Video]
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					VideoPreview(video: video)
				}
			}
			.padding()
		}
	}
}

/// Auto-loading VideoGrid.
struct AutoVideoGrid<Value: Equatable>: View {
	let value: Value
	let fetch: (Int) async throws -> [Video]
	
	@State private var videos: [Video] = []
	@State private var page = 1
	
	/// Auto-loading VideoGrid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, videos are refreshed. The value must conform to the `Equatable` protocol.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	init(id value: Value, fetch: @escaping (Int) async throws -> [Video]) {
		self.value = value
		self.fetch = fetch
	}
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					VideoPreview(video: video)
						.task {
							if video == videos.last {
								print("Last video did appear, loading next page")
								do {
									videos += try await fetch(page + 1)
									page += 1
								} catch APIError.invalidServerResponse(errorCode: 404) {
									print("Last page")
								}
							}
						}
				}
			}
			.padding()
			.refreshable {
				try await refreshVideos()
			}
		}
		.refreshable {
			try await refreshVideos()
		}
		#if os(macOS)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				refreshButton
			}
		}
		#else
		.background {
			refreshButton
				.hidden()
		}
		#endif
		.task(id: value) {
			print("Load Videos")
			try await refreshVideos()
		}
	}
	
	private var refreshButton: some View {
		AsyncButton {
			try await refreshVideos()
		} label: {
			Image(systemName: "arrow.clockwise")
		}
		.asyncButtonStyle(.progress(replacesLabel: true))
		.keyboardShortcut("r", modifiers: .command)
	}
	
	private func refreshVideos() async throws {
		let newVideos = try await fetch(1)
		if newVideos != videos {
			print("Video list changed")
			page = 1
			withAnimation {
				videos = newVideos
			}
		}
	}
}

extension AutoVideoGrid where Value == Bool {
	/// Auto-loading VideoGrid.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	init(fetch: @escaping (Int) async throws -> [Video]) {
		self.value = false
		self.fetch = fetch
	}
}

struct VideoGrid_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
