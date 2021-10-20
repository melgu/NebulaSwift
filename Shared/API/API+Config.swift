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
	
	enum CodingKeys: String, CodingKey {
		case platform, environment, features, recommendedVersion = "recommended_version",
			 minimumVersion = "minimum_version", appStoreUrl = "app_store_url",
			 authBaseUrl = "auth_base_url", contentBaseUrl = "content_base_url"
		
	}
}

extension API {
	var config: Config {
		get async throws {
			let url = URL(string: "https://config.watchnebula.com/ios.prod.json")!
			let (data, response) = try await URLSession.shared.data(from: url)
			
			guard let httpResponse = response as? HTTPURLResponse else {
				throw APIError.invalidServerResponse(errorCode: nil)
			}
			guard httpResponse.statusCode == 200 else {
				throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
			}
			
			let config = try JSONDecoder().decode(Config.self, from: data)
			return config
		}
	}
}
