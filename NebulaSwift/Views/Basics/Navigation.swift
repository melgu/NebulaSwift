//
//  Navigation.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.04.22.
//

import SwiftUI
import OSLog

// MARK: Action

struct OpenItemAction {
	let action: (any Item) -> Void
	
	init(_ action: @escaping (any Item) -> Void) {
		self.action = action
	}
	
	func callAsFunction(_ item: any Item) {
		action(item)
	}
	
	typealias Item = Hashable & Sendable
}

// MARK: - Environment

extension EnvironmentValues {
	/// Set a handler for errors.
	///
	/// The default error handler prints errors that occur.
	@Entry var openItem: OpenItemAction = OpenItemAction({ print("openItem environment has not been set. \($0)") })
}

extension View {
	func onOpenItem(perform action: @escaping (any Hashable & Sendable) -> Void) -> some View {
		environment(\.openItem, OpenItemAction(action))
	}
}

// MARK: - Player Dismissal

extension EnvironmentValues {
	/// Counts how often the player has been closed, so the content behind it can refresh.
	@Entry var playerDismissalCount = 0
}

extension View {
	/// Runs an action whenever the player is closed while this view is on screen.
	func onPlayerDismiss(perform action: @escaping @MainActor () async throws -> Void) -> some View {
		modifier(OnPlayerDismissModifier(action: action))
	}
}

fileprivate struct OnPlayerDismissModifier: ViewModifier {
	let action: @MainActor () async throws -> Void
	
	@Environment(\.playerDismissalCount) private var playerDismissalCount
	@Environment(\.handleError) private var handleError
	
	/// Views further down a navigation stack stay alive, but only the one on top needs to refresh right away.
	@State private var isVisible = false
	/// Whether the player was closed while this view was hidden, so it refreshes once it's back on screen.
	///
	/// The player covers this view too, and it may only report being back after the player reported being closed.
	@State private var needsRefresh = false
	
	func body(content: Content) -> some View {
		content
			.onAppear {
				isVisible = true
				if needsRefresh {
					logger.debug("Refresh deferred until now")
					needsRefresh = false
					runAction()
				}
			}
			.onDisappear { isVisible = false }
			.onChange(of: playerDismissalCount) {
				if isVisible {
					logger.debug("Refresh")
					runAction()
				} else {
					logger.debug("Defer refresh until visible")
					needsRefresh = true
				}
			}
	}
	
	private func runAction() {
		Task {
			do {
				try await action()
			} catch {
				handleError(error)
			}
		}
	}
}

private let logger = Logger(category: "OnPlayerDismissModifier")

struct Navigation_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
