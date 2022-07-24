//
//  HeroPreview.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import SwiftUI

struct HeroPreview: View {
	let hero: Hero
	
	@EnvironmentObject private var api: API
	
	var body: some View {
		AsyncNavigationLink {
			try await api.channel(for: hero.slug)
		} label: { _ in
			HeroPreviewView(hero: hero)
		}
		.buttonStyle(.plain)
		.controlSize(.large)
		.asyncButtonStyle(.progress(replacesLabel: false))
	}
}

struct HeroPreviewView: View {
	let hero: Hero
	
	var body: some View {
		VStack(alignment: .leading) {
			AsyncImage(url: hero.assets.mobileHero.original) { image in
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
