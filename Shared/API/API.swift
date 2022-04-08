//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation
import os.log

@MainActor class API: ObservableObject {
	let storage = Storage()
	
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
	
	@Published var isLoggedIn = false
	
	let logger = Logger(category: "API")
	
	init() {
		print("Token: \(storage.token ?? "nil")")
		print("Authorization: \(storage.bearer ?? "nil")")
		print("Zype Access Token: \(storage.zypeAuthInfo.accessToken ?? "nil")")
		print("Zype Refresh: \(storage.zypeAuthInfo.refreshToken ?? "nil")")
		
		storage.$token
			.combineLatest(storage.$bearer, storage.zypeAuthInfo.$accessToken)
			.map { $0 != nil && $1 != nil && $2 != nil }
			.assign(to: &$isLoggedIn)
	}
}
