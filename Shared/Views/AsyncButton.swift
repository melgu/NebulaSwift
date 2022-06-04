//
//  AsyncButton.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 29.04.22.
//

import SwiftUI

struct AsyncButton<Label: View>: View {
	private let role: ButtonRole?
	private let action: Action
	private let label: () -> Label
	
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
		}
		.disabled(isRunning)
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

struct AsyncButton_Previews: PreviewProvider {
    static var previews: some View {
		AsyncButton {
			try? await Task.sleep(nanoseconds: 2_000_000_000)
		} label: {
			Text("Button")
		}
    }
}
