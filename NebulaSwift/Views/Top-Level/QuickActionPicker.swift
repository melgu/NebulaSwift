//
//  QuickActionPicker.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.10.26.
//

#if os(iOS)
import SwiftUI
import OSLog

private let logger = Logger(category: "QuickActionPicker")

/// Picks a page or a channel to add as a quick action.
struct QuickActionPicker: View {
	@Environment(API.self) private var api
	@Environment(Storage.self) private var storage
	@Environment(\.dismiss) private var dismiss

	@State private var myShows: [Channel]?
	@State private var myShowsError: Error?
	@State private var searchTerm = ""

	var body: some View {
		List {
			let pages = filtered(StartPage.allCases.map(QuickAction.page) + [.search])
			if !pages.isEmpty {
				Section("Home") {
					ForEach(pages, content: row)
				}
			}
			Section("My Shows") {
				if let myShows {
					ForEach(filtered(myShows.map(QuickAction.init)), content: row)
				} else if let myShowsError {
					LoadingErrorView(error: myShowsError) {
						Task { await loadMyShows() }
					}
				} else {
					ProgressView()
						.frame(maxWidth: .infinity)
				}
			}
		}
		.searchable(text: $searchTerm)
		.autocorrectionDisabled()
		.navigationTitle("Add Quick Action")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await loadMyShows()
		}
	}

	private func row(for action: QuickAction) -> some View {
		let isAdded = storage.quickActions.contains(action)
		return Button {
			storage.quickActions.append(action)
			dismiss()
		} label: {
			HStack {
				Label(action.title, systemImage: action.systemImage)
					.foregroundStyle(isAdded ? .secondary : .primary)
				Spacer()
				if isAdded {
					Image(systemName: "checkmark")
						.foregroundStyle(.tint)
						.accessibilityLabel("Added")
				}
			}
		}
		.disabled(isAdded)
	}

	private func filtered(_ actions: [QuickAction]) -> [QuickAction] {
		guard !searchTerm.isEmpty else { return actions }
		return actions.filter { $0.title.localizedStandardContains(searchTerm) }
	}

	private func loadMyShows() async {
		myShowsError = nil
		do {
			myShows = try await api.libraryChannels(offset: 0, pageSize: 200)
		} catch {
			guard !error.isCancellation else { return }
			logger.error("Loading My Shows failed. Error: \(error)")
			myShowsError = error
		}
	}
}
#endif
