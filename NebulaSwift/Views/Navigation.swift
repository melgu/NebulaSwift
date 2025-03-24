//
//  Navigation.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.04.22.
//

import SwiftUI

// MARK: Action

struct OpenItemAction: Sendable {
	let action: @Sendable (any Item) -> Void
	
	init(_ action: @escaping @Sendable (any Item) -> Void) {
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
	func onOpenItem(perform action: @escaping @Sendable (any Hashable & Sendable) -> Void) -> some View {
		environment(\.openItem, OpenItemAction(action))
	}
}

struct Navigation_Previews: PreviewProvider {
	static var previews: some View {
		Text("No preview")
	}
}
