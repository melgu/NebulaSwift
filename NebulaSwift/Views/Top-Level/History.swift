//
//  History.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.10.26.
//

import SwiftUI

struct History: View {
	@Environment(API.self) private var api
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.historyVideos(page: page)
		})
		.navigationTitle("History")
	}
}

struct History_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		History()
			.environment(api)
	}
}
