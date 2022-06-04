//
//  AsyncNavigationLink.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 09.05.22.
//

import SwiftUI

struct AsyncNavigationLink<Item, Destination: View, Label: View>: View {
	let fetch: () async throws -> Item
	let destination: (Item) -> Destination
	let label: (Status<Item>) -> Label
	
	@Environment(\.errorHandler) private var errorHandler
	
	@State private var state: Status<Item> = .idle
	
	init(
		fetch: @escaping () async throws -> Item,
		destination: @escaping (Item) -> Destination,
		@ViewBuilder label: @escaping (AsyncNavigationLink<Item, Destination, Label>.Status<Item>) -> Label
	) {
		self.fetch = fetch
		self.destination = destination
		self.label = label
	}
	
	var body: some View {
		AsyncButton {
			do {
				state = .loading
				let item = try await fetch()
				state = .success(item)
			} catch {
				state = .failure(error)
				errorHandler(error)
			}
		} label: {
			label(state)
		}
		.navigation(item: $state.value) { item in
			destination(item)
		}
	}
}

extension AsyncNavigationLink {
	enum Status<Item> {
		case idle
		case loading
		case success(Item)
		case failure(Error)
		
		var value: Item? {
			get {
				if case .success(let item) = self {
					return item
				} else {
					return nil
				}
			}
			set {
				if let newValue = newValue {
					self = .success(newValue)
				} else {
					self = .idle
				}
			}
		}
	}
}

struct AsyncNavigationLink_Previews: PreviewProvider {
    static var previews: some View {
		AsyncNavigationLink {
			try await Task.sleep(nanoseconds: 2_000_000_000)
			return "Destination"
		} destination: { item in
			Text(verbatim: item)
		} label: { status in
			switch status {
			case .idle:
				Text("Idle")
			case .loading:
				Text("Loading")
			case .success:
				Text("Success")
			case .failure:
				Text("Failure")
			}
		}
    }
}
