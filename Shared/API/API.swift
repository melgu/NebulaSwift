//
//  API.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

enum API {}

enum APIError: Error {
	case invalidServerResponse
	case missingToken
}


enum HTTPMethod {}

extension HTTPMethod {
	static let get = "GET"
	static let post = "POST"
	static let put = "PUT"
	static let delete = "DELETE"
}
