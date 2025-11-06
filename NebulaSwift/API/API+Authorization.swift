//
//  Authorization.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 20.10.21.
//

import Foundation

struct AuthorizationResponse: Decodable {
	let token: String
}

extension API {
	var authorization: AuthorizationResponse {
		get async throws {
			let url = try URL(string: "\(authBaseURL)/api/v1/authorization/").require()
			return try await request(.post, url: url, authorization: .token)
		}
	}
	
	func refreshAuthorization() async throws {
		let authResponse = try await self.authorization
		bearer = authResponse.token
	}
}
