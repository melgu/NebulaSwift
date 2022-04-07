//
//  VideoView.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoView: View {
	let video: Video
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var didAppearOnce = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				Color.black
					.aspectRatio(16/9, contentMode: .fit)
					.overlay(CustomVideoPlayer())
					.task {
						guard !didAppearOnce else { return }
						didAppearOnce = true
						print("Load Video Stream Info")
						do {
							try await player.replaceVideo(with: video)
							player.play()
						} catch {
							print(error)
						}
					}
				
				#if os(macOS)
				HStack {
					Text(video.title)
						.font(.title)
					Spacer()
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
				#endif
				Text(video.description)
				if let categorySlugs = video.categorySlugs {
					HStack {
						ForEach(categorySlugs, id: \.self) { category in
							Text(category)
								.padding(8)
								.background(
									RoundedRectangle(cornerRadius: 4)
										.foregroundColor(.blue)
										.opacity(0.2)
								)
						}
					}
				}
			}
			.padding()
			.navigationTitle(video.title)
			#if canImport(UIKit)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					ShareButton(items: [video.shareUrl]) {
						Image(systemName: "square.and.arrow.up")
					}
				}
			}
			#endif
		}
	}
}

struct VideoView_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
