//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import OSLog

@MainActor @Observable
class API {
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
	
	/// The login token, kept in the Keychain.
	@ObservationIgnored var token: String? {
		didSet { Self.store(token, account: Defaults.token) }
	}
	/// The authorization for the content API, kept in the Keychain.
	@ObservationIgnored var bearer: String? {
		didSet { Self.store(bearer, account: Defaults.bearer) }
	}
	
	/// Does **not** contain trailing "/" from my experience.
	@ObservationIgnored @AppStorage(Defaults.authBaseURL) var authBaseURL: String = "https://users.api.nebula.app"
	
	/// Does contain trailing "/" from my experience.
	@ObservationIgnored @AppStorage(Defaults.contentBaseURL) var contentBaseURL: String = "https://content.api.nebula.app/"
	
	var isLoggedIn = false
	
	let logger = Logger(category: "API")
	
	init() {
		token = Self.load(account: Defaults.token)
		bearer = Self.load(account: Defaults.bearer)
		logger.debug("Token: \(self.token ?? "nil")")
		logger.debug("Authorization: \(self.bearer ?? "nil")")
		
		isLoggedIn = token != nil && bearer != nil
	}
	
	/// Reads a value from the Keychain, moving it there from UserDefaults where older versions kept it.
	private static func load(account: String) -> String? {
		do {
			if let value = try Keychain.load(account: account) {
				return value
			}
		} catch {
			Logger(category: "API").error("Couldn't read \(account) from Keychain. Error: \(error)")
			return nil
		}
		
		guard let legacyValue = UserDefaults.standard.string(forKey: account) else { return nil }
		// Keep the value in UserDefaults if moving fails, so the login isn't lost
		do {
			try Keychain.save(legacyValue, account: account)
			UserDefaults.standard.removeObject(forKey: account)
		} catch {
			Logger(category: "API").error("Couldn't move \(account) to Keychain. Error: \(error)")
		}
		return legacyValue
	}
	
	private static func store(_ value: String?, account: String) {
		do {
			if let value {
				try Keychain.save(value, account: account)
			} else {
				try Keychain.delete(account: account)
			}
		} catch {
			Logger(category: "API").error("Couldn't update \(account) in Keychain. Error: \(error)")
		}
		// Older versions kept it there
		UserDefaults.standard.removeObject(forKey: account)
	}
	
	func refreshConfiguration() async throws {
		let appConfig = try await self.appConfig
		self.authBaseURL = appConfig.authBaseURL
		self.contentBaseURL = appConfig.contentBaseURL
	}
}
