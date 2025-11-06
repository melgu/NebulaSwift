//
//  API+AppConfig.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 16.05.25.
//

import Foundation

struct AppConfig: Codable {
	/// Does **not** contain trailing "/" from my experience.
	let authBaseURL: String
	
	/// Does contain trailing "/" from my experience.
	let contentBaseURL: String
	
//	let features: [Any?]
//	let platform: String
//	let environment: String
//	let appStoreURL: String
//	let signupEnabled: Bool
//	let minimumVersion: String
//	let minimumOSVersion: String
//	let recommendedVersion: String
//	let minimumOSVersionMessage: String
}

extension API {
	var appConfig: AppConfig {
		get async throws {
			let url = try URL(string: "\(contentBaseURL)app_configs/ios/").require()
			return try await request(.get, url: url, authorization: .none)
		}
	}
}
