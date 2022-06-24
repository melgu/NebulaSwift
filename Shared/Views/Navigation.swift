//
//  Navigation.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.04.22.
//

import SwiftUI

// MARK: Environment

private struct OpenItemKey: EnvironmentKey {
	static let defaultValue: (any Hashable) -> Void = { print($0) }
}

extension EnvironmentValues {
	/// Set a handler for errors.
	///
	/// The default error handler prints errors that occur.
	var openItem: (any Hashable) -> Void {
		get { self[OpenItemKey.self] }
		set { self[OpenItemKey.self] = newValue }
	}
}

struct Navigation_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
