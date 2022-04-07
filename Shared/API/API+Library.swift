//
//  API+Library.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 16.11.21.
//

import Foundation

extension API {
	func libraryVideos(page: Int, pageSize: Int = 20) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/library/video/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func libraryChannels(page: Int, pageSize: Int = 20) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/library/video/channels/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
}
