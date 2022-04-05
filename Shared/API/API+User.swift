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
	let zobjectUserId: String
	let zypeConsumer: ZypeConsumer
	let zypeAuthInfo: ZypeAuthInfo?
	let promotion: String?
	let iapStatus: String?
}

struct ZypeConsumer: Decodable {
	let zypeId: String
}

struct ZypeAuthInfo: Codable {
	let accessToken: String
	let expiresAt: Int
	let refreshToken: String
	let zypeCreatedAt: Int
}

extension API {
	var user: UserResponse {
		get async throws {
			let url = URL(string: "https://api.watchnebula.com/api/v1/auth/user/")!
			return try await request(.get, url: url, authorization: .token)
		}
	}
	
	func refreshZypeAuthorization() async throws {
		// TODO: If refresh token exist, use that method
		
		// Fetch additional authorization info
		let user = try await self.user
		storage.zypeAuthInfo.accessToken = user.zypeAuthInfo?.accessToken
		storage.zypeAuthInfo.expiresAt = user.zypeAuthInfo?.expiresAt
		storage.zypeAuthInfo.refreshToken = user.zypeAuthInfo?.refreshToken
	}
}
