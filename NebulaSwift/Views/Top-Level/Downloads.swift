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
					section("Downloading", videos: unfinished, detail: downloadStatus)
					section("Downloaded", videos: finished)
				}
				.padding()
			}
			.showDownloadDetails()
			.animation(.default, value: downloads.downloads.map(\.id))
		}
	}
	
	@ViewBuilder
	/// - Parameter detail: Shown at the header's end.
	private func section(_ title: LocalizedStringKey, videos: [Video], detail: String? = nil) -> some View {
		if !videos.isEmpty {
			Section {
				ForEach(videos, id: \.episodeId) { video in
					VideoPreview(video: video)
				}
			} header: {
				HStack(alignment: .firstTextBaseline) {
					Text(title)
						.font(.title2.bold())
					Spacer()
					if let detail {
						Text(detail)
							.font(.subheadline.monospacedDigit())
							.foregroundStyle(.secondary)
					}
				}
				.padding(.top)
			}
		}
	}
	
	/// Sends progress made offline first, so the server's engagement includes it.
	private func refreshEngagement() async {
		await player.progressSync.flush()
		await downloads.refreshEngagement()
	}
	
	/// The speed like “42.5 Mbit/s”, the unit connections are measured in, or that the running download is being converted.
	private var downloadStatus: String? {
		if unfinished.contains(where: { if case .processing = downloads.status(of: $0) { true } else { false } }) {
			return String(localized: "Converting…")
		}
		guard let bytesPerSecond = downloads.bytesPerSecond else { return nil }
		let megabits = bytesPerSecond * 8 / 1_000_000
		return "\(megabits.formatted(.number.precision(.fractionLength(1)))) Mbit/s"
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
