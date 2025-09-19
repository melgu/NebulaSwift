//
//  ChannelGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import SwiftUI
import OSLog

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
	
	/// Auto-loading ChannelGrid
	/// - Parameter fetch: Closure which loads the channels for a given page (1-indexed).
	init(fetch: @escaping (Int) async throws -> [Channel]) {
		self.fetch = fetch
	}
	
	var body: some View {
		AutoGrid(fetch: fetch) { channel in
			ChannelPreview(channel: channel)
		}
	}
}

struct ChannelGrid_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
