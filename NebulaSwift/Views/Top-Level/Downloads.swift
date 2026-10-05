//
//  Downloads.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Downloads: View {
	@Environment(DownloadManager.self) private var downloads
	@Environment(Player.self) private var player
	@Environment(\.handleError) private var handleError
	
	@State private var showDeleteConfirmation = false
	
	var body: some View {
		content
			.navigationTitle("Downloads")
			.toolbar {
				#if os(macOS)
				ToolbarItem {
					Button {
						downloads.showInFinder()
					} label: {
						Label("Show in Finder", systemImage: "folder")
					}
				}
				#endif
				if downloads.totalSize > 0 {
					ToolbarItem {
						Button {
							showDeleteConfirmation = true
						} label: {
							Text(downloads.totalSize.formatted(.byteCount(style: .file)))
						}
						.accessibilityLabel("Used Space")
						.accessibilityValue(downloads.totalSize.formatted(.byteCount(style: .file)))
						.confirmationDialog("Do you really want to delete all downloads?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
							Button("Delete All Downloads", role: .destructive) {
								do {
									try downloads.deleteAll()
								} catch {
									handleError(error)
								}
							}
						} message: {
							#if os(macOS)
							Text("Unfinished downloads are cancelled, and downloaded videos are moved to the Trash.")
							#else
							Text("Unfinished downloads are cancelled, and downloaded videos are deleted.")
							#endif
						}
					}
				}
			}
			.task {
				downloads.refreshFiles()
				await refreshEngagement()
			}
			.onPlayerDismiss {
				await refreshEngagement()
			}
	}
	
	@ViewBuilder
	private var content: some View {
		if downloads.downloads.isEmpty {
			ContentUnavailableView {
				Label("No Downloads", systemImage: "arrow.down.circle")
			} description: {
				Text("Download videos from their menu to watch them without a connection.")
			}
		} else {
			ScrollView {
				LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)], alignment: .leading) {
					section("Downloading", videos: unfinished)
					section("Downloaded", videos: finished)
				}
				.padding()
			}
			.showDownloadDetails()
			.animation(.default, value: downloads.downloads.map(\.id))
		}
	}
	
	@ViewBuilder
	private func section(_ title: LocalizedStringKey, videos: [Video]) -> some View {
		if !videos.isEmpty {
			Section {
				ForEach(videos, id: \.episodeId) { video in
					VideoPreview(video: video)
				}
			} header: {
				Text(title)
					.font(.title2.bold())
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.top)
			}
		}
	}
	
	/// Sends progress made offline first, so the server's engagement includes it.
	private func refreshEngagement() async {
		await player.progressSync.flush()
		await downloads.refreshEngagement()
	}
	
	/// In the order they download, with progress made offline.
	private var unfinished: [Video] {
		downloads.downloads.filter { $0.state != .finished }.map { player.progressSync.applying(to: $0.video) }
	}
	
	/// The latest first, with progress made offline.
	private var finished: [Video] {
		downloads.downloads.filter { $0.state == .finished }.sorted { $0.addedAt > $1.addedAt }.map { player.progressSync.applying(to: $0.video) }
	}
}

#Preview {
	@Previewable @State var api = API()
	@Previewable @State var storage = Storage()
	@Previewable @State var downloads = DownloadManager(api: API(), storage: Storage())
	
	Downloads()
		.environment(api)
		.environment(storage)
		.environment(downloads)
		.environment(Player(api: api, storage: storage, downloads: downloads))
}
