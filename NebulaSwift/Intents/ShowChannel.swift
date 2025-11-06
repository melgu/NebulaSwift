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
	var channel: Channel?
	
	static let title: LocalizedStringResource = "Show Channel"
	
	static let openAppWhenRun = true
	
	@MainActor
	func perform() async throws -> some IntentResult {
		guard let channel else {
			throw $channel.needsValueError("Which channel do you want to show?")
		}
		
		let url = try URL(string: "NebulaSwift://channel/\(channel.slug)").require()
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
