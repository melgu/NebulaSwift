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
			.environment(\.errorHandler) { error in
				print(error)
				if let error = error as? URLError, error.code == .cancelled { return }
				self.error = error
				isPresented = true
			}
			.alert("Error", isPresented: $isPresented, presenting: error) { _ in
				Button("OK") {}
			} message: { error in
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

// MARK: - onTapGesture

fileprivate struct OnTapGestureModifier: ViewModifier {
	let count: Int
	let action: @Sendable () async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	func body(content: Content) -> some View {
		content.onTapGesture(count: count) {
			Task {
				do {
					try await action()
				} catch {
					errorHandler(error)
				}
			}
		}
	}
}

fileprivate struct OnTapGestureWithCoordinateModifier: ViewModifier {
	let count: Int
	let coordinateSpace: CoordinateSpace
	let action: @MainActor @Sendable (CGPoint) async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	func body(content: Content) -> some View {
		content.onTapGesture(count: count, coordinateSpace: coordinateSpace) { point in
			Task {
				do {
					try await action(point)
				} catch {
					errorHandler(error)
				}
			}
		}
	}
}

extension View {
	func onTapGesture(count: Int = 1, perform action: @escaping @MainActor @Sendable () async throws -> Void) -> some View {
		modifier(OnTapGestureModifier(count: count, action: action))
	}
	
	func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping @MainActor @Sendable (CGPoint) async throws -> Void) -> some View {
		modifier(OnTapGestureWithCoordinateModifier(count: count, coordinateSpace: coordinateSpace, action: action))
	}
}

// MARK: - task

fileprivate struct TaskModifier: ViewModifier {
	let priority: TaskPriority
	let action: @MainActor @Sendable () async throws -> Void
	
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
	let action: @MainActor @Sendable () async throws -> Void
	
	@Environment(\.errorHandler) private var errorHandler
	
	init(id value: T, priority: TaskPriority, action: @MainActor @escaping @Sendable () async throws -> Void) {
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
	
	func task<T>(id value: T, priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async throws -> Void) -> some View where T : Equatable {
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
		VStack {
			AsyncButton("Throw first Error") {
				throw DemoError.unknown
			}
			AsyncButton("Throw second error") {
				throw DemoError.known(number: 1)
			}
		}
		.buttonStyle(.bordered)
		.alertErrorHandling()
    }
	
	private enum DemoError: Error, LocalizedError {
		case unknown
		case known(number: Int)
		
		var errorDescription: String? {
			switch self {
			case .unknown:
				return "Description: unknown"
			case .known(number: let number):
				return "Description: known \(number)"
			}
		}
	}
}
