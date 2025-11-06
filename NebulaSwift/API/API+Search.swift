//
//  API+Search.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import Foundation

extension API {
	func searchChannels(for searchTerm: String, offset: Int = 1, pageSize: Int = 24) async throws -> [Channel] {
		let percentEncoded = try searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).require()
		let url = try URL(string: "https://content.watchnebula.com/search/channel/video/?text=\(percentEncoded)&offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `searchChannels(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	func searchChannels(for searchTerm: String, page: Int = 1, pageSize: Int = 24) async throws -> [Channel] {
		try await searchChannels(for: searchTerm, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func searchVideos(for searchTerm: String, offset: Int = 1, pageSize: Int = 24) async throws -> [Video] {
		let percentEncoded = try searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).require()
		let url = try URL(string: "https://content.watchnebula.com/search/video/?text=\(percentEncoded)&offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `searchVideos(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	func searchVideos(for searchTerm: String, page: Int = 1, pageSize: Int = 24) async throws -> [Video] {
		try await searchVideos(for: searchTerm, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
}
