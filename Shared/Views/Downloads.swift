//
//  Downloads.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Downloads: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
    var body: some View {
		Text("Downloads")
			.onAppear {
				player.reset()
			}
			.settingsSheet()
    }
}

struct Downloads_Previews: PreviewProvider {
    static var previews: some View {
        Downloads()
    }
}
