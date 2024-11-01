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
	let trialCancelled: Bool
	let isSubscribed: Bool
	let isPasswordSet: Bool
	let hasCuriositystreamSubscription: Bool
	let promotion: String?
	let iapStatus: String?
}

extension API {
	var user: UserResponse {
		get async throws {
			let url = URL(string: "https://api.watchnebula.com/api/v1/auth/user/")!
			return try await request(.get, url: url, authorization: .token)
		}
	}
}
