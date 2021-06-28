//
//  API+Login.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import Foundation

struct LoginRequestBody: Encodable {
	let email: String
	let password: String
}

struct LoginResponse: Decodable {
	let key: String
}

extension API {
	static func login(email: String, password: String) async throws -> String {
		let url = URL(string: "https://api.watchnebula.com/api/v1/auth/login/")!
		var request = URLRequest(url: url)
		
		request.httpMethod = HTTPMethod.post
		request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
		
		let requestBody = LoginRequestBody(email: email, password: password)
		request.httpBody = try JSONEncoder().encode(requestBody)
		
		let (data, response) = try await URLSession.shared.data(for: request)
		
		guard let httpResponse = response as? HTTPURLResponse else {
			throw APIError.invalidServerResponse(errorCode: nil)
		}
		guard httpResponse.statusCode == 200 else {
			throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
		}
		
		let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
		return loginResponse.key
	}
}
