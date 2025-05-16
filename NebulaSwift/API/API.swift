//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import OSLog

@MainActor
class API: ObservableObject {
	let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}()
	
	let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.dateEncodingStrategy = .iso8601
		return encoder
	}()
	
	@AppStorage(Defaults.token) var token: String?
	@AppStorage(Defaults.bearer) var bearer: String?
	
	/// Does **not** contain trailing "/" from my experience.
	@AppStorage(Defaults.authBaseURL) var authBaseURL: String = "https://users.api.nebula.app"
	
	/// Does contain trailing "/" from my experience.
	@AppStorage(Defaults.contentBaseURL) var contentBaseURL: String = "https://content.api.nebula.app/"
	
	@Published var isLoggedIn = false
	
	let logger = Logger(category: "API")
	
	init() {
		logger.debug("Token: \(self.token ?? "nil")")
		logger.debug("Authorization: \(self.bearer ?? "nil")")
		
		isLoggedIn = token != nil && bearer != nil
	}
	
	func refreshConfiguration() async throws {
		let appConfig = try await self.appConfig
		self.authBaseURL = appConfig.authBaseURL
		self.contentBaseURL = appConfig.contentBaseURL
	}
}
