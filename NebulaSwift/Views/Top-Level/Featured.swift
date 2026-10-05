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
	/// Why the features couldn't be loaded initially, shown in their place until a load succeeds.
	@State private var loadError: Error?
	
	var body: some View {
		ScrollView(.vertical) {
			if featured.isEmpty, loading != nil {
				ProgressView()
					.controlSize(.large)
					.frame(maxWidth: .infinity)
					.containerRelativeFrame(.vertical)
			} else if featured.isEmpty, let loadError {
				LoadingErrorView(error: loadError, retry: loadFeatured)
					.containerRelativeFrame(.vertical)
			} else {
				VStack(alignment: .leading, spacing: 32) {
					ForEach(featured) { feature in
						row(for: feature)
					}
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
		.onPlayerDismiss {
			guard loading == nil else { return }
			try await refreshFeatured(animated: true)
		}
		.onAppear {
			// Pushing this view cancels a `.task` mid-flight without ever starting it again, which
			// leaves the page empty on iPhone, so the load outlives the view's appearance instead.
			guard featured.isEmpty, loading == nil else { return }
			loadFeatured()
		}
	}

	private func loadFeatured() {
		loadError = nil
		loading = Task {
			defer { loading = nil }
			do {
				try await refreshFeatured(animated: false)
			} catch {
				if !error.isCancellation {
					loadError = error
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
								.containerRelativeFrame(.horizontal) { width, _ in
									min(480, width - 32)
								}
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
				.accessibilityLabel("Refresh")
		}
		.asyncButtonStyle(.progress(replacesLabel: true))
		.keyboardShortcut("r", modifiers: .command)
	}
	
	private func refreshFeatured(animated: Bool) async throws {
		let featured = try await api.featured()
		loadError = nil
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
			.environment(Player(api: api, storage: Storage()))
	}
}
