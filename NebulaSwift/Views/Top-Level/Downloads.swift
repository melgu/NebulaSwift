//
//  Downloads.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Downloads: View {
	@Environment(DownloadManager.self) private var downloads
	
	var body: some View {
		content
			.navigationTitle("Downloads")
			#if os(macOS)
			.navigationSubtitle(downloads.totalSize > 0 ? downloads.totalSize.formatted(.byteCount(style: .file)) : "")
			.toolbar {
				ToolbarItem {
					Button {
						downloads.showInFinder()
					} label: {
						Label("Show in Finder", systemImage: "folder")
					}
				}
			}
			#endif
			.task {
				downloads.refreshFiles()
				await downloads.refreshEngagement()
			}
			.onPlayerDismiss {
				await downloads.refreshEngagement()
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
				#if os(iOS)
				if downloads.totalSize > 0 {
					Text("\(downloads.totalSize.formatted(.byteCount(style: .file))) in total")
						.font(.footnote)
						.foregroundStyle(.secondary)
						.padding(.bottom)
				}
				#endif
			}
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
	
	/// In the order they download.
	private var unfinished: [Video] {
		downloads.downloads.filter { $0.state != .finished }.map(\.video)
	}
	
	/// The latest first.
	private var finished: [Video] {
		downloads.downloads.filter { $0.state == .finished }.sorted { $0.addedAt > $1.addedAt }.map(\.video)
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
