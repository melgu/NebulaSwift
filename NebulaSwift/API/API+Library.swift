//
//  API+Library.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 16.11.21.
//

import Foundation

extension API {
	func libraryVideos(offset: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "\(contentBaseURL)video_episodes/?following=true&offset=\(offset)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `libraryVideos(offset:pageSize:)` instead")
	@_disfavoredOverload
	func libraryVideos(page: Int, pageSize: Int = 24) async throws -> [Video] {
		try await libraryVideos(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func libraryChannels(offset: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "\(contentBaseURL)library/video/channels/?offset=\(offset)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `libraryChannels(offset:pageSize:)` instead")
	@_disfavoredOverload
	func libraryChannels(page: Int, pageSize: Int = 24) async throws -> [Channel] {
		try await libraryChannels(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
}
