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
		let url = try URL(string: "\(authBaseURL)/api/v1/auth/login/").require()
		let body = LoginRequestBody(email: email, password: password)
		
		Task.detached {
			URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
		}
		
		return try await request(.post, url: url, body: body, authorization: .none)
	}
	
	func login(email: String, password: String) async throws {
		// Actual login (get token)
		let loginResponse = try await self._login(email: email, password: password)
		token = loginResponse.key
		
		try await refreshAuthorization()
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
		isLoggedIn = true
	}
	
	@MainActor
	func logout() {
		isLoggedIn = false
		
		Task.detached {
			URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
		}
		
		token = nil
		bearer = nil
	}
}
