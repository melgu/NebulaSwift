//
//  Browse.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Browse: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
    var body: some View {
		VideoGrid(fetch: { page in
			try await api.allVideos(page: page)
		})
		.navigationTitle("Browse")
		.onAppear {
			player.reset()
		}
    }
}

struct Browse_Previews: PreviewProvider {
    static var previews: some View {
        Browse()
    }
}
