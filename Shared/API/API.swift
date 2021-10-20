//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

@MainActor class API: ObservableObject {
	let storage = Storage()
	
	@Published var isLoggedIn = false
	
	init() {
		storage.$token
			.combineLatest(storage.$bearer, storage.zypeAuthInfo.$accessToken)
			.map { $0 != nil && $1 != nil && $2 != nil }
			.assign(to: &$isLoggedIn)
	}
}
