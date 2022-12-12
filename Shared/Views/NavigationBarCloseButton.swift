//
//  NavigationBarCloseButton.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 12.12.22.
//

import SwiftUI

extension View {
	func navigationBarCloseButton(onDismiss action: @escaping () -> Void = {}) -> some View {
		modifier(NavigationBarCloseButtonModifier(action: action))
	}
}

private struct NavigationBarCloseButtonModifier: ViewModifier {
	@Environment(\.dismiss) private var dismiss
	
	let action: () -> Void
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button {
						action()
						dismiss()
					} label: {
						Label("Close", systemImage: "xmark.circle.fill")
					}
				}
			}
	}
}

struct NavigationBarCloseButton_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			Text("Demo")
				.navigationBarCloseButton()
		}
    }
}
