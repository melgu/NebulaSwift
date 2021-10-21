//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

@MainActor class API: ObservableObject {
	let storage = Storage()
	
	let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}()
	
	let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		return encoder
	}()
	
	@Published var isLoggedIn = false
	
	init() {
		storage.$token
			.combineLatest(storage.$bearer, storage.zypeAuthInfo.$accessToken)
			.map { $0 != nil && $1 != nil && $2 != nil }
			.assign(to: &$isLoggedIn)
	}
}
