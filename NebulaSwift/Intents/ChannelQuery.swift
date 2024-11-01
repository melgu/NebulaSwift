//
//  ChannelQuery.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 12.07.22.
//

import Foundation
import AppIntents

struct ChannelQuery: EntityStringQuery {
	func entities(for identifiers: [Channel.ID]) async throws -> [Channel] {
		let api = await API()
		var channels: [Channel] = []
		for identifier in identifiers {
			let channel = try await api.channel(for: identifier)
			channels.append(channel)
		}
		return channels
	}
	
	func suggestedEntities() async throws -> [Channel] {
		let api = await API()
		return try await api.libraryChannels(page: 1, pageSize: 100)
	}
	
	func entities(matching string: String) async throws -> [Channel] {
		let api = await API()
		return try await api.searchChannels(for: string)
	}
}
