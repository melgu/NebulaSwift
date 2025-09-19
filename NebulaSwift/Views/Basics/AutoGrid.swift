//
//  AutoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 19.09.25.
//

import SwiftUI
import OSLog

private let logger = Logger(category: "AutoVideoGrid")

/// Auto-loading Grid.
struct AutoGrid<Value: Equatable, Item: Identifiable & Equatable, Preview: View>: View {
	let value: Value
	let fetch: (Int) async throws -> [Item]
	let preview: (Item) -> Preview
	
	@State private var isInitialLoad = false
	@State private var items: [Item] = []
	@State private var page = 1
	
	/// Auto-loading Grid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, the items are refreshed.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	init(id value: Value, fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview) {
		self.value = value
		self.fetch = fetch
		self.preview = preview
	}
	
	var body: some View {
		Group {
			if isInitialLoad {
				ProgressView()
			} else {
				ScrollView {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
						ForEach(items) { item in
							preview(item)
								.task {
									if item == items.last {
										logger.debug("Last item did appear, loading next page")
										do {
											items += try await fetch(page + 1)
											page += 1
										} catch APIError.invalidServerResponse(errorCode: 404) {
											logger.debug("Last page")
										}
									}
								}
						}
					}
					.padding()
					.refreshable {
						try await refreshItems()
					}
				}
			}
		}
		.refreshable {
			try await refreshItems()
		}
		#if os(macOS)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				refreshButton
			}
		}
		#else
		.background {
			refreshButton
				.hidden()
		}
		#endif
		.task(id: value) {
			logger.debug("Load items")
			isInitialLoad = true
			defer { isInitialLoad = false }
			try await refreshItems()
		}
	}
	
	private var refreshButton: some View {
		AsyncButton {
			try await refreshItems()
		} label: {
			Image(systemName: "arrow.clockwise")
		}
		.asyncButtonStyle(.progress(replacesLabel: true))
		.keyboardShortcut("r", modifiers: .command)
	}
	
	private func refreshItems() async throws {
		logger.debug("Refresh items")
		let newItems = try await fetch(1)
		if newItems != items {
			logger.debug("Video list changed")
			page = 1
			withAnimation {
				items = newItems
			}
		}
	}
}

extension AutoGrid where Value == Bool {
	/// Auto-loading Grid that reloads when a specified value changes.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	init(fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview) {
		self.value = false
		self.fetch = fetch
		self.preview = preview
	}
}
