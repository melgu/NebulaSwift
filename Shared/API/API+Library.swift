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
			let url = URL(string: "https://content.watchnebula.com/library/video/?page=1")!
			let parameters: [String: String] = ["page": "1"]
			let response: VideoList = try await request(.get, url: url, parameters: parameters, authorization: .bearer)
			return response.results
		}
	}
}
