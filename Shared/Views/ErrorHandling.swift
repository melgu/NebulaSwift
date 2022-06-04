//
//  ErrorHandling.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.06.22.
//

import SwiftUI

// MARK: Environment

private struct ErrorHandlerKey: EnvironmentKey {
	static let defaultValue: (Error) -> Void = { print($0) }
}

extension EnvironmentValues {
	/// Set a handler for errors.
	///
	/// The default error handler prints errors that occur.
	var errorHandler: (Error) -> Void {
		get { self[ErrorHandlerKey.self] }
		set { self[ErrorHandlerKey.self] = newValue }
	}
}

// MARK: - Error Alert

fileprivate struct AlertErrorHandlerModifier: ViewModifier {
	@State private var error: Error?
	@State private var isPresented = false
	
	func body(content: Content) -> some View {
		content
			.environment(\.errorHandler) {
				error = $0
				isPresented = true
			}
			.alert("Error", isPresented: $isPresented, presenting: error) { error in
				Text(error.localizedDescription)
			}
	}
}

extension View {
	/// Handle errors with an alert, that displays the localized description.
	func alertErrorHandling() -> some View {
		modifier(AlertErrorHandlerModifier())
	}
}

// MARK: - task

fileprivate struct TaskModifier: ViewModifier {
	let priority: TaskPriority
	let action: @Sendable () async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	func body(content: Content) -> some View {
		content.task(priority: priority) {
			do {
				try await action()
			} catch {
				errorHandler(error)
			}
		}
	}
}

fileprivate struct TaskModifierWithID<T: Equatable>: ViewModifier {
	let value: T // ID
	let priority: TaskPriority
	let action: @Sendable () async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	init(id value: T, priority: TaskPriority, action: @escaping @Sendable () async throws -> Void) {
		self.value = value
		self.priority = priority
		self.action = action
	}
	
	func body(content: Content) -> some View {
		content.task(id: value, priority: priority) {
			do {
				try await action()
			} catch {
				errorHandler(error)
			}
		}
	}
}

extension View {
	func task(priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async throws -> Void) -> some View {
		modifier(TaskModifier(priority: priority, action: action))
	}
	
	func task<T>(id value: T, priority: TaskPriority = .userInitiated, _ action: @MainActor @escaping @Sendable () async throws -> Void) -> some View where T : Equatable {
		modifier(TaskModifierWithID(id: value, priority: priority, action: action))
	}
}

// MARK: - refreshable

fileprivate struct RefreshableModifier: ViewModifier {
	let action: @Sendable () async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	func body(content: Content) -> some View {
		content.refreshable {
			do {
				try await action()
			} catch {
				errorHandler(error)
			}
		}
	}
}

extension View {
	func refreshable(action: @MainActor @escaping @Sendable () async throws -> Void) -> some View {
		modifier(RefreshableModifier(action: action))
	}
}

struct ErrorHandling_Previews: PreviewProvider {
    static var previews: some View {
		AsyncButton("Throw Error") {
			throw DemoError.unknown
		}
		.alertErrorHandling()
    }
	
	private enum DemoError: Error {
		case unknown
	}
}
