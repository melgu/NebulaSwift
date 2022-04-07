//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct MyShows: View {
	@EnvironmentObject private var api: API
	
	var body: some View {
		VideoGrid(fetch: { page in
			try await api.libraryVideos(page: page)
		})
		.navigationTitle("My Shows")
		.settingsSheet()
	}
}

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
			.environmentObject(API())
    }
}
