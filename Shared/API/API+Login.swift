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
	private func _login(email: String, password: String) async throws -> LoginResponse {
		let url = URL(string: "https://api.watchnebula.com/api/v1/auth/login/")!
		var request = URLRequest(url: url)
		
		request.httpMethod = HTTPMethod.post
		request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
		
		let requestBody = LoginRequestBody(email: email, password: password)
		request.httpBody = try JSONEncoder().encode(requestBody)
		
		URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: Date.distantPast)
		
		let (data, response) = try await URLSession.shared.data(for: request)
		
		guard let httpResponse = response as? HTTPURLResponse else {
			throw APIError.invalidServerResponse(errorCode: nil)
		}
		guard httpResponse.statusCode == 200 else {
			throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
		}
		
		let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
		return loginResponse
	}
	
	func login(email: String, password: String) async throws {
		// Actual login (get token)
		let loginResponse = try await self._login(email: email, password: password)
		storage.token = loginResponse.key
		
		// Get Bearer token
		let authResponse = try await self.authorization
		storage.bearer = authResponse.token
		
		// Fetch additional authorization info
		let user = try await self.user
		storage.zypeAuthInfo.accessToken = user.zypeAuthInfo.accessToken
		storage.zypeAuthInfo.expiresAt = user.zypeAuthInfo.expiresAt
		storage.zypeAuthInfo.refreshToken = user.zypeAuthInfo.refreshToken
	}
	
	func logout() {
		URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: Date.distantPast)
		
		storage.token = nil
		storage.bearer = nil
		storage.zypeAuthInfo.accessToken = nil
		storage.zypeAuthInfo.refreshToken = nil
	}
}
