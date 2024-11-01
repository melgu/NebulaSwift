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
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				AsyncButton {
					statistics = try await fetch()
				} label: {
					Label("Statistics", systemImage: "info.circle")
				}
				.asyncButtonStyle(.progress(replacesLabel: true))
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
