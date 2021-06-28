//
//  API+User.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import Foundation

struct UserResponse: Decodable {
	let createdAt: Date
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
	let zypeAuthInfo: ZypeAuthInfo
	let promotion: String?
	let iapStatus: String?
	
	enum CodingKeys: String, CodingKey {
		case createdAt = "created_at", pk, email, name, accountType = "account_type",
			 promoExpiration = "promo_expiration", optInToCommunications = "opt_in_to_communications",
			 trialCancelled = "trial_cancelled", isSubscribed = "is_subscribed",
			 isPasswordSet = "is_password_set", hasCuriositystreamSubscription = "has_curiositystream_subscription",
			 zobjectUserId = "zobject_user_id", zypeConsumer = "zype_consumer",
			 zypeAuthInfo = "zype_auth_info", promotion, iapStatus = "iap_status"
	}
}

struct ZypeConsumer: Decodable {
	let zypeId: String
	
	enum Codingkeys: String, CodingKey {
		case zypeId = "zype_id"
	}
}

struct ZypeAuthInfo: Decodable {
	let accessToken: String
	let expiresAt: Int
	let refreshToken: String
	let zypeCreatedAt: Int
	
	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token", expiresAt = "expires_at",
		refreshToken = "refresh_token", zypeCreatedAt = "zype_created_at"
		
	}
}

extension API {
	static func user() async throws -> UserResponse {
		guard !Settings.shared.token.isEmpty else { throw APIError.missingToken }
		let url = URL(string: "https://api.watchnebula.com/api/v1/auth/login/")!
		var request = URLRequest(url: url)
		request.setValue("Token \(Settings.shared.token)", forHTTPHeaderField: "Authorization")
		
		let (data, response) = try await URLSession.shared.data(from: url)
		
		guard let httpResponse = response as? HTTPURLResponse,
			  httpResponse.statusCode == 200 else {
				  throw APIError.invalidServerResponse
			  }
		
		let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
		return userResponse
	}
}
