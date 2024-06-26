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
		let body = LoginRequestBody(email: email, password: password)
		
		URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: Date.distantPast)
		
		return try await request(.post, url: url, body: body, authorization: .none)
	}
	
	func login(email: String, password: String) async throws {
		// Actual login (get token)
		let loginResponse = try await self._login(email: email, password: password)
		storage.token = loginResponse.key
		
		try await refreshAuthorization()
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
	}
	
	@MainActor
	func logout() {
		URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: Date.distantPast)
		
		storage.token = nil
		storage.bearer = nil
	}
}
