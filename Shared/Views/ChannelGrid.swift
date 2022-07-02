//
//  ChannelGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import SwiftUI

struct ChannelGrid: View {
	let channels: [Channel]
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(channels) { channel in
					ChannelPreview(channel: channel)
				}
			}
			.padding()
		}
	}
}

/// Auto-loading ChannelGrid
struct AutoChannelGrid: View {
	let fetch: (Int) async throws -> [Channel]
	
	@State private var channels: [Channel] = []
	@State private var page = 1
	
	/// Auto-loading ChannelGrid
	/// - Parameter fetch: Closure which loads the channels for a given page (1-indexed)
	init(fetch: @escaping (Int) async throws -> [Channel]) {
		self.fetch = fetch
	}
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(channels) { channel in
					ChannelPreview(channel: channel)
						.task {
							if channel == channels.last {
								print("Last channel did appear, loading next page")
								do {
									channels += try await fetch(page + 1)
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
			try await refreshChannels()
		}
		.toolbar {
			#if canImport(UIKit)
			ToolbarItem(placement: .navigationBarTrailing) {
				refreshButton
			}
			#else
			ToolbarItem(placement: .navigation) {
				refreshButton
			}
			#endif
		}
		.task {
			print("Load Channels")
			try await refreshChannels()
		}
	}
	
	private var refreshButton: some View {
		AsyncButton {
			print("Refresh Channels")
			try await refreshChannels()
		} label: {
			Image(systemName: "arrow.clockwise")
		}
		.asyncButtonStyle(.progress)
	}
	
	private func refreshChannels() async throws {
		let newChannels = try await fetch(1)
		if newChannels != channels {
			print("Video list changed")
			page = 1
			withAnimation {
				channels = newChannels
			}
		}
	}
}

struct ChannelGrid_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
