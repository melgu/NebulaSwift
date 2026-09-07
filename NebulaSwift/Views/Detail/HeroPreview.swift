//
//  HeroPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import SwiftUI

struct HeroPreview: View {
	let hero: Hero
	
	@Environment(API.self) private var api
	
	var body: some View {
		Group {
			switch hero.destination {
			case .video(let slug):
				AsyncNavigationLink {
					try await api.video(for: slug)
				} label: { _ in
					HeroPreviewView(hero: hero)
				}
			case .channel(let slug):
				AsyncNavigationLink {
					try await api.channel(for: slug)
				} label: { _ in
					HeroPreviewView(hero: hero)
				}
			case nil:
				HeroPreviewView(hero: hero)
			}
		}
		.buttonStyle(.plain)
		.controlSize(.large)
		.asyncButtonStyle(.progress(replacesLabel: false))
		.contextMenu(for: hero)
	}
}

struct HeroPreviewView: View {
	/// The artwork comes in 3:1, 2:1 and 16:9, so the card settles on one shape and crops to it.
	static let aspectRatio: CGFloat = 2/1
	
	let hero: Hero
	
	var body: some View {
		VStack(alignment: .leading) {
			Color.black
				.aspectRatio(HeroPreviewView.aspectRatio, contentMode: .fit)
				.overlay {
					AsyncImage(url: hero.images.backgroundWide[960]) { image in
						image
							.resizable()
							.scaledToFill()
					} placeholder: {
						EmptyView()
					}
				}
				.cornerRadius(8)
			
			Text(hero.title)
		}
		.lineLimit(2)
	}
}

struct HeroPreview_Previews: PreviewProvider {
	static var previews: some View {
		Text("No Preview")
	}
}
