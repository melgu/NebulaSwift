//
//  VideoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

/// Auto-loading VideoGrid
struct VideoGrid: View {
	let fetch: (Int) async throws -> [Video]
	
	@EnvironmentObject private var player: Player
	
	@State private var videos: [Video] = []
	@State private var page = 1
	
	/// Auto-loading VideoGrid
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	init(fetch: @escaping (Int) async throws -> [Video]) {
		self.fetch = fetch
	}
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					NavigationLink {
						VideoView(video: video)
					} label: {
						VideoPreview(video: video)
					}
					.buttonStyle(.plain)
					.contextMenu {
						Button("Watch later") {
							print("Watch later")
						}
						Button("Download") {
							print("Download")
						}
					}
					.task {
						if video == videos.last {
							print("Last video did appear, loading next page")
							do {
								videos += try await fetch(page + 1)
								page += 1
							} catch {
								print(error)
							}
						}
					}
				}
			}
			.padding()
		}
		.refreshable {
			print("Refresh Videos")
			await refreshVideos()
		}
		.task {
			player.reset()
			print("Load Videos")
			await refreshVideos()
		}
	}
	
	func refreshVideos() async {
		do {
			let newVideos = try await fetch(1)
			if newVideos != videos {
				print("Video list changed")
				page = 1
				videos = newVideos
			}
		} catch {
			print(error)
		}
	}
}

struct VideoGrid_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
