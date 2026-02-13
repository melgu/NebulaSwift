//
//  Downloads.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Downloads: View {
	@EnvironmentObject private var api: API
	@Environment(Player.self) private var player
	
	var body: some View {
		Text("Coming soon…")
			.foregroundColor(.secondary)
			.navigationTitle("Downloads")
	}
}

struct Downloads_Previews: PreviewProvider {
	static var previews: some View {
		Downloads()
	}
}
