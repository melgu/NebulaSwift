//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

struct ContentView: View {
	@StateObject var model = Model()
	
    var body: some View {
		TabView(selection: $model.tab) {
			Featured()
				.tabItem { Label("Featured", systemImage: "star.circle") }
				.tag(Tabs.featured)
			MyShows()
				.tabItem { Label("My Shows", systemImage: "suit.heart") }
				.tag(Tabs.myShows)
			Browse()
				.tabItem { Label("Browse", systemImage: "list.dash") }
				.tag(Tabs.browse)
			Downloads()
				.tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
				.tag(Tabs.downloads)
			Search()
				.tabItem { Label("Search", systemImage: "magnifyingglass") }
				.tag(Tabs.search)
		}
		.task {
			await model.setup()
		}
		.onChange(of: Settings.shared.token, perform: model.tokenChanged)
		.sheet(isPresented: $model.loginIsPresented) {
			Login()
		}
    }
}

extension ContentView {
	enum Tabs {
		case featured
		case myShows
		case browse
		case downloads
		case search
	}
}

extension ContentView {
	class Model: ObservableObject {
		@Published var tab: Tabs = .browse
		@Published var loginIsPresented = false
		
		private var cancellables = Set<AnyCancellable>()
		
		func setup() async {
			do {
				let config = try await API.config()
				Settings.shared.nebulaAuthApi = config.authBaseUrl.absoluteString
				Settings.shared.nebulaContentApi = config.contentBaseUrl.absoluteString
			} catch {
				show(error: error)
			}
			
			if Settings.shared.token.isEmpty {
				loginIsPresented = true
			}
		}
		
		func tokenChanged(to token: String) {
			if token.isEmpty {
				loginIsPresented = true
			}
		}
		
		func show(error: Error) {
			print("Something went wrong:\n\(error)")
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
