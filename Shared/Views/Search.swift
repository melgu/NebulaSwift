//
//  Search.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Search: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
    var body: some View {
        Text("Search")
			.onAppear {
				player.reset()
			}
    }
}

struct Search_Previews: PreviewProvider {
    static var previews: some View {
        Search()
    }
}
