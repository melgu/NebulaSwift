//
//  ShowChannel.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 12.07.22.
//

import Foundation
import AppIntents
import SwiftUI

struct ShowChannel: AppIntent {
	@Parameter(title: "Channel")
	var channel: Channel
	
	static var title: LocalizedStringResource = "Show Channel"
	
	static var openAppWhenRun = true
	
	@MainActor
	func perform() async throws -> some IntentResult {
		let url = URL(string: "NebulaSwift://channel/\(channel.slug)")!
		#if os(iOS)
		_ = await UIApplication.shared.open(url)
		#else
		NSWorkspace.shared.open(url)
		#endif
		return .result()
	}
	
	static var parameterSummary: IntentParameterSummary<ShowChannel> {
		Summary("Show \(\.$channel)")
	}
}
