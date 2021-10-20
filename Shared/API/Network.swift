//
//  Network.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 20.10.21.
//

import Foundation

enum APIError: Error {
	case invalidServerResponse(errorCode: Int?)
	case missingToken
}

enum HTTPMethod {}

extension HTTPMethod {
	static let get = "GET"
	static let head = "HEAD"
	static let post = "POST"
	static let put = "PUT"
	static let delete = "DELETE"
	static let connect = "CONNECT"
	static let options = "OPTIONS"
	static let trace = "TRACE"
	static let patch = "PATCH"
}
