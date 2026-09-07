//
//  Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Featured: View {
	@Environment(API.self) private var api
	@Environment(Player.self) private var player
	
	@State private var featured: [Feature] = []
	@State private var loading: Task<Void, Never>?
	
	@Environment(\.handleError) private var handleError
	
	var body: some View {
		ScrollView(.vertical) {
			VStack(alignment: .leading, spacing: 32) {
				ForEach(featured) { feature in
					row(for: feature)
				}
			}
		}
		.refreshable {
			try await refreshFeatured(animated: true)
		}
		.navigationTitle("Featured")
		#if os(macOS)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				refreshButton
			}
		}
		#else
		.background {
			refreshButton
				.hidden()
		}
		#endif
		.onAppear {
			// Pushing this view cancels a `.task` mid-flight without ever starting it again, which
			// leaves the page empty on iPhone, so the load outlives the view's appearance instead.
			guard featured.isEmpty, loading == nil else { return }
			loading = Task {
				defer { loading = nil }
				do {
					try await refreshFeatured(animated: false)
				} catch {
					handleError(error)
				}
			}
		}
	}
	
	@ViewBuilder
	private func row(for feature: Feature) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			switch feature.items {
			case .heroes:
				EmptyView()
			default:
				Text(feature.title)
					.font(.title)
					.bold()
					.padding(.horizontal)
			}
			
			ScrollView(.horizontal) {
				HStack(alignment: .top) {
					switch feature.items {
					case .heroes(let array):
						ForEach(array) { item in
							HeroPreview(hero: item)
								.frame(width: 480)
						}
					case .videos(let array):
						ForEach(array) { item in
							VideoPreview(video: item)
								.frame(width: 240)
						}
					case .channels(let array):
						ForEach(array) { item in
							ChannelPreview(channel: item)
								.frame(width: 240)
						}
					case .podcasts(let array):
						ForEach(array) { item in
							PodcastPreview(podcast: item)
								.frame(width: 200)
						}
					case .classes:
						Text("Coming soon…")
					}
				}
				.padding()
				.refreshable {
					try await refreshFeatured(animated: true)
				}
			}
		}
	}
	
	private var refreshButton: some View {
		AsyncButton {
			try await refreshFeatured(animated: true)
		} label: {
			Image(systemName: "arrow.clockwise")
		}
		.asyncButtonStyle(.progress(replacesLabel: true))
		.keyboardShortcut("r", modifiers: .command)
	}
	
	private func refreshFeatured(animated: Bool) async throws {
		let featured = try await api.featured()
		if featured != self.featured {
			if animated {
				withAnimation {
					self.featured = featured
				}
			} else {
				self.featured = featured
			}
		}
	}
}

struct Featured_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		Featured()
			.environment(api)
			.environment(Player(api: api))
	}
}
