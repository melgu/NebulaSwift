//
//  VideoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI
import OSLog

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
struct AutoVideoGrid<Value: Equatable, Header: View>: View {
	let value: Value
	let fetch: (Int) async throws -> [Video]
	let header: Header
	
	/// Auto-loading VideoGrid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, videos are refreshed.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed).
	/// - Parameter header: Content above the videos that scrolls with them.
	init(id value: Value, fetch: @escaping (Int) async throws -> [Video], @ViewBuilder header: () -> Header) {
		self.value = value
		self.fetch = fetch
		self.header = header()
	}
	
	var body: some View {
		AutoGrid(id: value, fetch: fetch) { video in
			VideoPreview(video: video)
		} header: {
			header
		}
	}
}

extension AutoVideoGrid where Header == EmptyView {
	/// Auto-loading VideoGrid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, videos are refreshed.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed).
	init(id value: Value, fetch: @escaping (Int) async throws -> [Video]) {
		self.init(id: value, fetch: fetch) { EmptyView() }
	}
}

extension AutoVideoGrid where Value == Bool {
	/// Auto-loading VideoGrid.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	/// - Parameter header: Content above the videos that scrolls with them.
	init(fetch: @escaping (Int) async throws -> [Video], @ViewBuilder header: () -> Header) {
		self.init(id: false, fetch: fetch, header: header)
	}
}

extension AutoVideoGrid where Value == Bool, Header == EmptyView {
	/// Auto-loading VideoGrid.
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	init(fetch: @escaping (Int) async throws -> [Video]) {
		self.init(id: false, fetch: fetch) { EmptyView() }
	}
}

struct VideoGrid_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
