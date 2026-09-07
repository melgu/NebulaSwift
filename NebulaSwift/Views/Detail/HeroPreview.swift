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
	let hero: Hero
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: hero.images.backgroundWide[960]) { image in
				image
					.resizable()
					.scaledToFit()
			} placeholder: {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
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
