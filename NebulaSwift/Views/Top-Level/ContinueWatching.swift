//
//  ContinueWatching.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.10.26.
//

import SwiftUI

struct ContinueWatching: View {
	@Environment(API.self) private var api
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.continueVideos(page: page)
		})
		.navigationTitle("Continue")
	}
}

struct ContinueWatching_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		ContinueWatching()
			.environment(api)
	}
}
