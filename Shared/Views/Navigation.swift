//
//  Navigation.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.04.22.
//

import SwiftUI

extension View {
	func navigation<Item, Destination: View>(item: Binding<Item?>, destination: @escaping (Item) -> Destination) -> some View {
		modifier(NavigationModifier(item: item, destination: destination))
	}
}

fileprivate struct NavigationModifier<Item, Destination: View>: ViewModifier {
	@Binding var item: Item?
	var destination: (Item) -> Destination
	
	var isActive: Binding<Bool> {
		Binding {
			item != nil
		} set: { newValue in
			if !newValue {
				item = nil
			}
		}
	}
	
	func body(content: Content) -> some View {
		content
			.background(
				NavigationLink(isActive: isActive) {
					if let item = item {
						destination(item)
					}
				} label: {
					EmptyView()
				}
			)
	}
}

struct Navigation_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
