//
//  AsyncNavigationLink.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 09.05.22.
//

import SwiftUI

struct AsyncNavigationLink<Item: Hashable, Label: View, Destination: View>: View {
	private let fetch: () async throws -> Item
	private let label: (Status<Item>) -> Label
	private let destination: (Item) -> Destination
	private let variant: Variant
	
	@Environment(\.openItem) private var openItem
	@Environment(\.errorHandler) private var errorHandler
	
	@State private var state: Status<Item> = .idle
	@State private var isPresented = false
	
	init(
		fetch: @escaping () async throws -> Item,
		@ViewBuilder label: @escaping (AsyncNavigationLink<Item, Label, Destination>.Status<Item>) -> Label,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) {
		self.fetch = fetch
		self.label = label
		self.destination = destination
		self.variant = .destination
	}
	
	var body: some View {
		AsyncButton {
			do {
				state = .loading
				let item = try await fetch()
				state = .success(item)
				switch variant {
				case .openItem:
					openItem(item)
				case .destination:
					/// Workaround. Without it, the `navigationDestination` reads an old state value (`loading`) and never updates.
					/// Seems like a bug in SwiftUI.
					// TODO: Prepare bug report
					Task { @MainActor in
						isPresented = true
					}
				}
			} catch {
				state = .failure(error)
				errorHandler(error)
			}
		} label: {
			label(state)
		}
		.navigationDestination(isPresented: $isPresented) {
			if case .success(let item) = state {
				destination(item)
			}
		}
	}
	
	private enum Variant {
		case openItem
		case destination
	}
}

extension AsyncNavigationLink where Label == Text {
	init(
		_ titleKey: LocalizedStringKey,
		fetch: @escaping () async throws -> Item,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) {
		self.fetch = fetch
		self.label = { _ in Text(titleKey) }
		self.destination = destination
		self.variant = .destination
	}
	
	init<S: StringProtocol>(
		_ title: S,
		fetch: @escaping () async throws -> Item,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) {
		self.fetch = fetch
		self.label = { _ in Text(title) }
		self.destination = destination
		self.variant = .destination
	}
}

extension AsyncNavigationLink where Destination == EmptyView {
	init(
		fetch: @escaping () async throws -> Item,
		@ViewBuilder label: @escaping (AsyncNavigationLink<Item, Label, Destination>.Status<Item>) -> Label
	) {
		self.fetch = fetch
		self.label = label
		self.destination = { _ in EmptyView() }
		self.variant = .openItem
	}
}

extension AsyncNavigationLink where Label == Text, Destination == EmptyView {
	init(
		_ titleKey: LocalizedStringKey,
		fetch: @escaping () async throws -> Item
	) {
		self.fetch = fetch
		self.label = { _ in Text(titleKey) }
		self.destination = { _ in EmptyView() }
		self.variant = .openItem
	}
	
	init<S: StringProtocol>(
		_ title: S,
		fetch: @escaping () async throws -> Item
	) {
		self.fetch = fetch
		self.label = { _ in Text(title) }
		self.destination = { _ in EmptyView() }
		self.variant = .openItem
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

private struct Demo: View {
	@State private var path = NavigationPath()
	
	var body: some View {
		NavigationStack(path: $path) {
			VStack {
				AsyncNavigationLink { () -> String in
					try await Task.sleep(nanoseconds: 2_000_000_000)
					return "Label Test"
				} label: { status in
					switch status {
					case .idle:
						Text("Item Idle")
					case .loading:
						Text("Loading")
					case .success:
						Text("Success")
					case .failure:
						Text("Failure")
					}
				}
				
				AsyncNavigationLink("Item", fetch: fetch)
				
				AsyncNavigationLink("Destination", fetch: fetch) { string in
					destination(for: string)
				}
				
				AsyncNavigationLink(fetch: fetch) { status in
					switch status {
					case .idle:
						Text("Destination Idle")
					case .loading:
						Text("Loading")
					case .success:
						Text("Success")
					case .failure:
						Text("Failure")
					}
				} destination: { string in
					destination(for: string)
				}
			}
			.buttonStyle(.borderedProminent)
			.environment(\.openItem) { item in
				path.append(item)
			}
			.navigationDestination(for: String.self, destination: destination)
			.navigationTitle("Demo")
		}
	}
	
	func fetch() async throws -> String {
		try await Task.sleep(nanoseconds: 200_000_000)
		return "Navigation Item"
	}
	
	func destination(for string: String) -> some View {
		Text(string)
			.navigationTitle("Destination")
	}
}

struct AsyncNavigationLink_Previews: PreviewProvider {
    static var previews: some View {
		Demo()
    }
}
