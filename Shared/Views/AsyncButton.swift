//
//  AsyncButton.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 29.04.22.
//

import SwiftUI

/// Loading indication style for ``AsyncButton``.
enum AsyncButtonStyle {
	/// Shows the button as disabled.
	case disabled
	
	/// Shows an indeterminate progress view without a label.
	case progress
}

struct AsyncButton<Label: View>: View {
	private let role: ButtonRole?
	private let action: Action
	private let label: () -> Label
	
	@Environment(\.asyncButtonStyle) private var asyncButtonStyle
	@Environment(\.errorHandler) private var errorHandler
	
	@State private var isRunning = false
	
	init(action: @escaping Action, @ViewBuilder label: @escaping () -> Label) {
		self.role = nil
		self.action = action
		self.label = label
	}
	
	var body: some View {
		Button(role: role) {
			Task {
				do {
					isRunning = true
					try await action()
					isRunning = false
				} catch {
					isRunning = false
					errorHandler(error)
				}
			}
		} label: {
			label()
				.opacity(showProgressView ? 0 : 1)
				.overlay(progressView)
		}
		.disabled(isRunning)
	}
	
	@ViewBuilder
	private var progressView: some View {
		if showProgressView {
			ProgressView()
		}
	}
	
	private var showProgressView: Bool {
		isRunning && asyncButtonStyle == .progress
	}
	
	typealias Action = @MainActor @Sendable () async throws -> Void
}

extension AsyncButton where Label == Text {
	init(_ titleKey: LocalizedStringKey, action: @escaping Action) {
		self.role = nil
		self.action = action
		self.label = { Text(titleKey) }
	}
	
	init<S: StringProtocol>(_ title: S, action: @escaping Action) {
		self.role = nil
		self.action = action
		self.label = { Text(title) }
	}
}

extension AsyncButton {
	init(role: ButtonRole?, action: @escaping Action, @ViewBuilder label: @escaping () -> Label) {
		self.role = role
		self.action = action
		self.label = label
	}
}

extension AsyncButton where Label == Text {
	init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping Action) {
		self.role = role
		self.action = action
		self.label = { Text(titleKey) }
	}
	
	init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping Action) {
		self.role = role
		self.action = action
		self.label = { Text(title) }
	}
}

// MARK: AsyncButtonStyle

private struct AsyncButtonStyleKey: EnvironmentKey {
	static let defaultValue: AsyncButtonStyle = .disabled
}

extension EnvironmentValues {
	fileprivate var asyncButtonStyle: AsyncButtonStyle {
		get { self[AsyncButtonStyleKey.self] }
		set { self[AsyncButtonStyleKey.self] = newValue }
	}
}

extension View {
	/// Sets the loading indication style for buttons within this view.
	///
	/// Use this modifier to set a specific style for button instances
	/// within a view:
	///
	///     HStack {
	///         AsyncButton("Sign In", action: signIn)
	///         AsyncButton("Register", action: register)
	///     }
	///     .asyncButtonStyle(.progress)
	///
	func asyncButtonStyle(_ style: AsyncButtonStyle) -> some View {
		environment(\.asyncButtonStyle, style)
	}
}

struct AsyncButton_Previews: PreviewProvider {
    static var previews: some View {
		AsyncButton {
			try? await Task.sleep(nanoseconds: 2_000_000_000)
		} label: {
			Text("Button")
		}
    }
}
