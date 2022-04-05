//
//  API+Config.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

struct Config: Decodable {
	let platform: String
	let environment: String
	let features: [String]
	let recommendedVersion: String
	let minimumVersion: String
	let appStoreUrl: URL
	let authBaseUrl: URL
	let contentBaseUrl: URL
}

extension API {
	var config: Config {
		get async throws {
			let url = URL(string: "https://config.watchnebula.com/ios.prod.json")!
			return try await request(.get, url: url, authorization: .none)
		}
	}
}
