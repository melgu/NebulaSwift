//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct MyShows: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	var body: some View {
		VideoGrid(fetch: { page in
			try await api.libraryVideos(page: page)
		})
		.navigationTitle("My Shows")
		.onAppear {
			player.reset()
		}
	}
}

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
			.environmentObject(API())
    }
}
