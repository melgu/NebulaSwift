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
	let zypeAuthInfo: ZypeAuthInfo
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
			guard let token = storage.token else { throw APIError.missingToken }
			
			let url = URL(string: "https://api.watchnebula.com/api/v1/auth/user/")!
			var request = URLRequest(url: url)
			request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
			
			let (data, response) = try await URLSession.shared.data(from: url)
			
			guard let httpResponse = response as? HTTPURLResponse else {
				throw APIError.invalidServerResponse(errorCode: nil)
			}
			guard httpResponse.statusCode == 200 else {
				throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
			}
			
			let userResponse = try decoder.decode(UserResponse.self, from: data)
			return userResponse
		}
	}
}
