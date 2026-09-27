//
//  AutoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 19.09.25.
//

import SwiftUI
import OSLog

private let logger = Logger(category: "AutoGrid")

/// Auto-loading Grid.
struct AutoGrid<Value: Equatable, Item: Identifiable & Equatable, Preview: View, Header: View>: View {
	private let value: Value
	private let fetch: (Int) async throws -> [Item]
	private let preview: (Item) -> Preview
	private let header: Header
	
	/// Index offset indicating when the next page is loaded.
	///
	/// The next page is loaded when the X-th last item is shown, with X being the `loadingOffset`.
	private let loadingOffset = 4
	
	@State private var isInitialLoad = false
	@State private var items: [Item] = []
	@State private var itemsCount = 0
	@State private var page = 1
	@State private var onLastPage = false
	@State private var deepestIndex = -1
	@State private var loading: Task<Void, Never>?
	@State private var paging: Task<Void, Never>?
	
	@Environment(\.handleError) private var handleError
	
	/// Auto-loading Grid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, the items are refreshed.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	/// - Parameter header: Content above the items that scrolls with them.
	init(id value: Value, fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview, @ViewBuilder header: () -> Header) {
		self.value = value
		self.fetch = fetch
		self.preview = preview
		self.header = header()
	}
	
	var body: some View {
		// One scroll view for both states, so the header keeps its place and state while the items load,
		// and the navigation bar never picks up a scroll view inside the header instead.
		ScrollView {
			header
			if isInitialLoad {
				ProgressView()
					.controlSize(.large)
					.frame(maxWidth: .infinity)
					.containerRelativeFrame(.vertical)
			} else {
				VStack {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
						ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
							preview(item)
								.onAppear {
									deepestIndex = max(deepestIndex, index)
								}
						}
						if !onLastPage {
							ProgressView()
								.controlSize(.large)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
						}
					}
				}
				.padding()
				.refreshable {
					try await refreshItems()
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
		.onAppear {
			// Pushing this view cancels a `.task` mid-flight without ever starting it again, which
			// leaves the grid empty on iPhone, so the loads outlive the view's appearance instead.
			guard items.isEmpty, loading == nil else { return }
			loadItems()
		}
		.onChange(of: value) {
			loadItems()
		}
		.onChange(of: shouldLoadNextPage) { _, shouldLoad in
			if shouldLoad {
				loadNextPages()
			}
		}
	}
	
	/// Whether the reader has come close enough to the end of the loaded items to load the next page.
	///
	/// Stays false until the first page is in, so a page load can't race the initial one.
	private var shouldLoadNextPage: Bool {
		!items.isEmpty && !onLastPage && deepestIndex >= itemsCount - 1 - loadingOffset
	}
	
	/// Replaces the items with the first page, showing a spinner in place of the grid meanwhile.
	private func loadItems() {
		logger.debug("Load items")
		loading?.cancel()
		isInitialLoad = true
		loading = Task {
			do {
				try await refreshItems()
			} catch {
				// A newer load cancelled this one and owns the state from here on.
				guard !Task.isCancelled else { return }
				handleError(error)
			}
			isInitialLoad = false
			loading = nil
		}
	}
	
	/// Loads pages until the reader is no longer close to the end of the loaded items.
	private func loadNextPages() {
		guard paging == nil else { return }
		paging = Task {
			while shouldLoadNextPage {
				logger.debug("Last item did appear, loading next page")
				do {
					let newItems = try await fetch(page + 1)
					// A refresh reset the list while this page was in flight.
					guard !Task.isCancelled else { return }
					if newItems.isEmpty {
						logger.debug("Last page")
						onLastPage = true
					} else {
						items += newItems
						itemsCount = items.count
						page += 1
					}
				} catch APIError.invalidServerResponse(errorCode: 404) {
					logger.debug("Last page")
					onLastPage = true
				} catch {
					guard !Task.isCancelled else { return }
					handleError(error)
					break
				}
			}
			paging = nil
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
		if newItems.isEmpty {
			onLastPage = true
		}
		if newItems != items {
			logger.debug("Video list changed")
			// The next page is counted from the new first page, so a load in flight is stale.
			paging?.cancel()
			paging = nil
			page = 1
			onLastPage = newItems.isEmpty
			deepestIndex = -1
			itemsCount = newItems.count
			withAnimation {
				items = newItems
			}
		}
	}
}

extension AutoGrid where Header == EmptyView {
	/// Auto-loading Grid that reloads when a specified value changes.
	/// - Parameter id: The value to observe for changes. When the value changes, the items are refreshed.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	init(id value: Value, fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview) {
		self.init(id: value, fetch: fetch, preview: preview) { EmptyView() }
	}
}

extension AutoGrid where Value == Bool {
	/// Auto-loading Grid.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	/// - Parameter header: Content above the items that scrolls with them.
	init(fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview, @ViewBuilder header: () -> Header) {
		self.init(id: false, fetch: fetch, preview: preview, header: header)
	}
}

extension AutoGrid where Value == Bool, Header == EmptyView {
	/// Auto-loading Grid.
	/// - Parameter fetch: Closure which loads the items for a given page (1-indexed).
	/// - Parameter preview: A closure that produces the preview for an individual item.
	init(fetch: @escaping (Int) async throws -> [Item], preview: @escaping (Item) -> Preview) {
		self.init(id: false, fetch: fetch, preview: preview) { EmptyView() }
	}
}
