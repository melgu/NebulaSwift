//
//  LiveSession.swift
//  NebulaSwiftLiveTests
//

import Foundation
import Testing
@testable import NebulaSwift

/// The logged-in API all live tests share.
///
/// The tests keep their own login in the Keychain, so a failing request that logs out, or a bug in the API layer,
/// can't touch the app's login. The first run copies the app's login token, which then lives on separately.
/// To copy it again, e.g. after logging in to the app with another account, delete the Keychain items of ``keychainService``.
@MainActor
enum LiveSession {
	static let keychainService = "de.melgu.NebulaSwift.tests"
	
	private static var shared: Task<API, Error>?
	
	static func api() async throws -> API {
		if let shared {
			return try await shared.value
		}
		let task = Task { try await makeAPI() }
		shared = task
		return try await task.value
	}
	
	private static func makeAPI() async throws -> API {
		try copyLoginIfMissing()
		let api = API(keychainService: keychainService)
		guard api.token != nil else {
			throw LiveSessionError("The login in the Keychain under \(keychainService) is incomplete. Delete it to copy the app's login again.")
		}
		// Checks the endpoint that hands out the authorization, too
		try await api.refreshAuthorization()
		return api
	}
	
	private static func copyLoginIfMissing() throws {
		guard try Keychain.load(account: Defaults.token, service: keychainService) == nil else {
			return
		}
		guard let token = try Keychain.load(account: Defaults.token) else {
			throw LiveSessionError("No login to test with. Log in to the app on this device first.")
		}
		try Keychain.save(token, account: Defaults.token, service: keychainService)
	}
}

struct LiveSessionError: Error, CustomStringConvertible {
	let description: String
	
	init(_ description: String) {
		self.description = description
	}
}

/// Content the tests read. It's checked only loosely, as Nebula may change it.
enum TestItems {
	static let channelSlug = "realengineering"
	static let channelTitle = "Real Engineering"
	static let categorySlug = "engineering"
	static let searchTerm = "engineering"
}

/// Runs the live tests one after the other, to go easy on the API.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct LiveTests {}
