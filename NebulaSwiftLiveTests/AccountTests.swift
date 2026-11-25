//
//  AccountTests.swift
//  NebulaSwiftLiveTests
//

import Foundation
import Testing
@testable import NebulaSwift

extension LiveTests {
	@MainActor @Suite struct Account {
		/// The app takes its base URLs from there, and builds requests on the trailing slashes being as they are.
		@Test func appConfig() async throws {
			let api = try await LiveSession.api()
			let config = try await api.appConfig
			
			#expect(config.authBaseURL.hasPrefix("https://"))
			#expect(!config.authBaseURL.hasSuffix("/"))
			#expect(config.contentBaseURL.hasPrefix("https://"))
			#expect(config.contentBaseURL.hasSuffix("/"))
		}
		
		@Test func user() async throws {
			let api = try await LiveSession.api()
			let user = try await api.user
			
			#expect(user.email.contains("@"))
			#expect(user.isSubscribed, "Most content needs a subscription")
		}
		
		@Test func authorization() async throws {
			let api = try await LiveSession.api()
			let authorization = try await api.authorization
			
			#expect(!authorization.token.isEmpty)
		}
	}
}
