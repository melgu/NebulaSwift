//
//  Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Featured: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
    var body: some View {
		Text("Featured")
			.onAppear { player.reset() }
    }
}

struct Featured_Previews: PreviewProvider {
    static var previews: some View {
        Featured()
    }
}
