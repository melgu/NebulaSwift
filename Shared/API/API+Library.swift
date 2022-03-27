//
//  API+Library.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 16.11.21.
//

import Foundation

extension API {
	var libraryVideos: [Video] {
		get async throws {
			try await libraryVideos(page: 1)
		}
	}
	
	func libraryVideos(page: Int) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/library/video/?page=\(page)")!
		let response: VideoList = try await request(.get, url: url, parameters: [:], authorization: .bearer)
		return response.results
	}
}
