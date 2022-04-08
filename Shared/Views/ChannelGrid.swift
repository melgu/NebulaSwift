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
			print("Refresh Channels")
			await refreshChannels()
		}
		.task {
			print("Load Channels")
			await refreshChannels()
		}
	}
	
	func refreshChannels() async {
		do {
			let newChannels = try await fetch(1)
			if newChannels != channels {
				print("Video list changed")
				page = 1
				channels = newChannels
			}
		} catch {
			print(error)
		}
	}
}

struct ChannelGrid_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
