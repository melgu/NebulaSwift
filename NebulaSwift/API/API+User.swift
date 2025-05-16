//
//  API+User.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import Foundation

struct UserResponse: Decodable {
	let createdAt: String
	let pk: Int
	let email: String
	let name: String
	let accountType: String
	let promoExpiration: String?
	let optInToCommunications: Bool
	let collectVideoAnalytics: Bool
//	let agreedToTerms: NSNull
	let trialCancelled: Bool
	let isSubscribed: Bool
	let isPasswordSet: Bool
	let hasCuriositystreamSubscription: Bool
	let zobjectUserID: String
//	let zypeConsumer: NSNull
//	let zypeAuthInfo: NSNull
	let promotion: String?
	let iapStatus: String?
//	let subscription: NSNull
	let entitlements: [String]
	let emailVerified: Bool
	let isStaff: Bool
}


extension API {
	var user: UserResponse {
		get async throws {
			let url = URL(string: "\(storage.authBaseURL)/api/v1/auth/user/")!
			return try await request(.get, url: url, authorization: .token)
		}
	}
}
