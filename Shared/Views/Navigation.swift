//
//  Navigation.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.04.22.
//

import SwiftUI

// MARK: Action

struct OpenItemAction {
	let action: (any Hashable) -> Void
	
	init(_ action: @escaping (any Hashable) -> Void) {
		self.action = action
	}
	
	func callAsFunction(_ item: any Hashable) {
		action(item)
	}
}

// MARK: - Environment

private struct OpenItemKey: EnvironmentKey {
	static let defaultValue: OpenItemAction = OpenItemAction({ print("openItem environment has not been set. \($0)") })
}

extension EnvironmentValues {
	/// Set a handler for errors.
	///
	/// The default error handler prints errors that occur.
	var openItem: OpenItemAction {
		get { self[OpenItemKey.self] }
		set { self[OpenItemKey.self] = newValue }
	}
}

extension View {
	func onOpenItem(perform action: @escaping (any Hashable) -> Void) -> some View {
		environment(\.openItem, OpenItemAction(action))
	}
}

struct Navigation_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
