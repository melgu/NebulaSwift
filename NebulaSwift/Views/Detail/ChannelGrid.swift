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
struct AutoChannelGrid<Header: View>: View {
	let fetch: @MainActor @Sendable (Int) async throws -> [Channel]
	let header: Header
	
	/// Auto-loading ChannelGrid
	/// - Parameter fetch: Closure which loads the channels for a given page (1-indexed).
	/// - Parameter header: Content above the channels that scrolls with them.
	init(fetch: @escaping @MainActor @Sendable (Int) async throws -> [Channel], @ViewBuilder header: () -> Header) {
		self.fetch = fetch
		self.header = header()
	}
	
	var body: some View {
		AutoGrid(fetch: fetch) { channel in
			ChannelPreview(channel: channel)
		} header: {
			header
		}
	}
}

extension AutoChannelGrid where Header == EmptyView {
	/// Auto-loading ChannelGrid
	/// - Parameter fetch: Closure which loads the channels for a given page (1-indexed).
	init(fetch: @escaping @MainActor @Sendable (Int) async throws -> [Channel]) {
		self.init(fetch: fetch) { EmptyView() }
	}
}

struct ChannelGrid_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
