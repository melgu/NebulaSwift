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
			guard let token = storage.token else { throw APIError.missingToken }
			
			let url = URL(string: "https://api.watchnebula.com/api/v1/authorization/")!
			var request = URLRequest(url: url)
			
			request.httpMethod = HTTPMethod.post
			request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
			
			let (data, response) = try await URLSession.shared.data(for: request)
			
			guard let httpResponse = response as? HTTPURLResponse else {
				throw APIError.invalidServerResponse(errorCode: nil)
			}
			guard httpResponse.statusCode == 200 else {
				throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
			}
			
			let authResponse = try JSONDecoder().decode(AuthorizationResponse.self, from: data)
			return authResponse
		}
	}
}
