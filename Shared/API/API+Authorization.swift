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
			let url = URL(string: "https://api.watchnebula.com/api/v1/authorization/")!
			return try await request(.post, url: url, parameters: [:], authorization: .token)
		}
	}
	
	func refreshAuthorization() async throws {
		let authResponse = try await self.authorization
		storage.bearer = authResponse.token
	}
}
