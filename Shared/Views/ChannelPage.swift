//
//  ChannelPage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct ChannelPage: View {
	let channel: Channel
	
	@EnvironmentObject private var api: API
	
	var body: some View {
		VideoGrid(fetch: { page in
			try await api.videos(for: channel, page: page)
		})
		.navigationTitle(channel.title)
	}
}

struct ChannelPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
