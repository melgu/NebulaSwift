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
	
	@State private var videos: [Video] = []
	@State private var page = 1
	
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
								videos += try await api.libraryVideos(page: page + 1)
								page += 1
							} catch {
								print(error)
							}
						}
					}
				}
			}
			.padding()
			.onAppear {
				player.reset()
			}
		}
		.navigationTitle("My Shows")
		.refreshable {
			print("Refresh Videos")
			await refreshVideos()
		}
		.task {
			print("Load Videos")
			await refreshVideos()
		}
		.settingsSheet()
	}
	
	func refreshVideos() async {
		do {
			let newVideos = try await api.libraryVideos(page: 1)
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

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
			.environmentObject(API())
    }
}
