//
//  StatisticsAlert.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 02.10.23.
//

import SwiftUI

extension View {
	func statisticsAlert(fetch: @escaping () async throws -> VideoListStatistics) -> some View {
		modifier(StatisticsAlertViewModifier(fetch: fetch))
	}
}

private struct StatisticsAlertViewModifier: ViewModifier {
	let fetch: () async throws -> VideoListStatistics
	
	@State private var statistics: VideoListStatistics?
	/// Lives here rather than in the button, so it survives the button being swapped for the progress view and can be cancelled when the list goes away.
	@State private var loadingTask: Task<Void, Never>?

	@Environment(\.handleError) private var handleError

	func body(content: Content) -> some View {
		content
			.toolbar {
				// The toolbar ignores the overlay `AsyncButton` uses for its progress view, so swap the button out instead.
				if loadingTask != nil {
					ProgressView()
				} else {
					Button("Statistics", systemImage: "info.circle", action: load)
				}
			}
			.onDisappear {
				loadingTask?.cancel()
				loadingTask = nil
			}
			.alert("Statistics", isPresented: $statistics.notNil, presenting: statistics) { _ in
				Button("OK") {
					statistics = nil
				}
			} message: { statistics in
				Text("""
				^[\(statistics.count) videos](inflect: true)
				Total duration: \(statistics.duration.formatted()) h
				""")
			}
	}

	private func load() {
		loadingTask = Task {
			do {
				let statistics = try await fetch()
				try Task.checkCancellation()
				self.statistics = statistics
			} catch {
				if !Task.isCancelled {
					handleError(error)
				}
			}
			// A cancelled task no longer owns the state, a newer one may have taken over.
			if !Task.isCancelled {
				loadingTask = nil
			}
		}
	}
}

private extension Optional {
	var notNil: Bool {
		get { self != nil }
		set {
			if !newValue {
				self = nil
			}
		}
	}
}

#Preview {
	let api = API()
	return NavigationStack {
		Text("Demo")
			.statisticsAlert {
				try await api.watchLaterStatistics()
			}
	}
}
