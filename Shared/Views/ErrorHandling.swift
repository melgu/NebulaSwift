//
//  ErrorHandling.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.06.22.
//

import SwiftUI

// MARK: Action

struct ErrorAction : Sendable{
	let action: @Sendable (Error) -> Void
	
	init(_ action: @escaping @Sendable (Error) -> Void) {
		self.action = action
	}
	
	func callAsFunction(_ error: Error) {
		action(error)
	}
}

// MARK: - Environment

private struct ErrorKey: EnvironmentKey {
	static let defaultValue: ErrorAction = ErrorAction({ print($0) })
}

extension EnvironmentValues {
	/// Set a handler for errors.
	///
	/// The default error handler prints errors that occur.
	var handleError: ErrorAction {
		get { self[ErrorKey.self] }
		set { self[ErrorKey.self] = newValue }
	}
}

extension View {
	func handleError(action: @escaping @Sendable (Error) -> Void) -> some View {
		environment(\.handleError, ErrorAction(action))
	}
}

// MARK: - Error Alert

fileprivate struct AlertErrorHandlerModifier: ViewModifier {
	@State private var error: Error?
	@State private var isPresented = false
	
	func body(content: Content) -> some View {
		content
			.handleError { error in
				print(error)
				if let error = error as? URLError, error.code == .cancelled { return }
				Task { @MainActor in
					self.error = error
					isPresented = true
				}
			}
			.alert("Something went wrong.", isPresented: $isPresented, presenting: error) { _ in
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
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.onTapGesture(count: count) {
			Task {
				do {
					try await action()
				} catch {
					handleError(error)
				}
			}
		}
	}
}

fileprivate struct OnTapGestureWithCoordinateModifier: ViewModifier {
	let count: Int
	let coordinateSpace: CoordinateSpace
	let action: @MainActor @Sendable (CGPoint) async throws -> Void
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.onTapGesture(count: count, coordinateSpace: coordinateSpace) { point in
			Task {
				do {
					try await action(point)
				} catch {
					handleError(error)
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
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.task(priority: priority) {
			do {
				try await action()
			} catch {
				handleError(error)
			}
		}
	}
}

fileprivate struct TaskModifierWithID<V: Equatable>: ViewModifier {
	let value: V // ID
	let priority: TaskPriority
	let action: @MainActor @Sendable () async throws -> Void
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.task(id: value, priority: priority) {
			do {
				try await action()
			} catch {
				handleError(error)
			}
		}
	}
}

extension View {
	func task(priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async throws -> Void) -> some View {
		modifier(TaskModifier(priority: priority, action: action))
	}
	
	func task<V>(id value: V, priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async throws -> Void) -> some View where V : Equatable {
		modifier(TaskModifierWithID(value: value, priority: priority, action: action))
	}
}

// MARK: - onChange

fileprivate struct OnChangeModifier<V: Equatable>: ViewModifier {
	let value: V
	let action: @MainActor @Sendable (V) async throws -> Void
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.onChange(of: value) { _, newValue in
			Task {
				do {
					try await action(newValue)
				} catch {
					handleError(error)
				}
			}
		}
	}
}

extension View {
	func onChange<V: Equatable>(of value: V, perform action: @escaping @MainActor @Sendable (V) async throws -> Void) -> some View {
		modifier(OnChangeModifier(value: value, action: action))
	}
}

// MARK: - refreshable

fileprivate struct RefreshableModifier: ViewModifier {
	let action: @MainActor @Sendable () async throws -> Void
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.refreshable {
			do {
				try await action()
			} catch {
				handleError(error)
			}
		}
	}
}

extension View {
	func refreshable(action: @MainActor @escaping @Sendable () async throws -> Void) -> some View {
		modifier(RefreshableModifier(action: action))
	}
}

// MARK: - onSubmit

fileprivate struct OnSubmitModifier: ViewModifier {
	let triggers: SubmitTriggers
	let action: @MainActor @Sendable () async throws -> Void
	
	@Environment(\.handleError) private var handleError
	
	func body(content: Content) -> some View {
		content.onSubmit {
			Task {
				do {
					try await action()
				} catch {
					handleError(error)
				}
			}
		}
	}
}

extension View {
	func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping @MainActor @Sendable () async throws -> Void) -> some View {
		modifier(OnSubmitModifier(triggers: triggers, action: action))
	}
}

// MARK: - Previews

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
