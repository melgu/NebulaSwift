//
//  API+Search.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import Foundation

extension API {
	func searchChannels(for searchTerm: String, page: Int = 1, pageSize: Int = 20) async throws -> [Channel] {
		let percentEncoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		let url = URL(string: "https://content.watchnebula.com/search/channel/video/?text=\(percentEncoded)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func searchVideos(for searchTerm: String, page: Int = 1, pageSize: Int = 20) async throws -> [Video] {
		let percentEncoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		let url = URL(string: "https://content.watchnebula.com/search/video/?text=\(percentEncoded)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
}
