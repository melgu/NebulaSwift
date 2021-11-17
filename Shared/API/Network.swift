//
//  Network.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 20.10.21.
//

import Foundation

enum APIError: Error {
	case invalidServerResponse(errorCode: Int)
	case networkIssues
	case missingToken
	case missingBearer
	case missingZypeAccessToken
}

extension API {
	enum AuthorizationType {
		case token
		case bearer
		case zypeAccess
	}
}

extension API {
	enum HTTPMethod: String {
		case get = "GET"
		case head = "HEAD"
		case post = "POST"
		case put = "PUT"
		case delete = "DELETE"
		case connect = "CONNECT"
		case options = "OPTIONS"
		case trace = "TRACE"
		case patch = "PATCH"
	}
}

extension API {
	private func setAuthorization(type authorizationType: AuthorizationType?, for request: inout URLRequest) throws {
		switch authorizationType {
		case .token:
			guard let token = storage.token else { throw APIError.missingToken }
			request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
		case .bearer:
			guard let bearer = storage.bearer else { throw APIError.missingBearer }
			request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
		case .zypeAccess:
			guard let zypeAccessToken = storage.zypeAuthInfo.accessToken else { throw APIError.missingZypeAccessToken }
			request.setValue("Token \(zypeAccessToken)", forHTTPHeaderField: "Authorization") // TODO: Token?
		case .none:
			break
		}
	}
	
	private func execute(request: URLRequest) async throws -> Data {
		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw APIError.networkIssues
		}
		guard httpResponse.statusCode == 200 else {
			throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode)
		}
		return data
	}
	
	private func _request<Result: Decodable>(_ method: HTTPMethod, url: URL, parameters: [String: String], body: Data?, authorization: AuthorizationType?) async throws -> Result {
		var request = URLRequest(url: url)
		
		request.httpMethod = method.rawValue
		request.httpBody = body
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.allHTTPHeaderFields = parameters
		
		try setAuthorization(type: authorization, for: &request)
		
		let data: Data
		do {
			data = try await execute(request: request)
		} catch let error as APIError {
			if case .invalidServerResponse(let code) = error, code == 403 {
				switch authorization {
				case .token:
					throw error
				case .bearer:
					try await refreshAuthorization()
				case .zypeAccess:
					try await refreshZypeAuthorization()
				case .none:
					throw error
				}
				try setAuthorization(type: authorization, for: &request)
				data = try await execute(request: request)
			} else {
				throw error
			}
		}
		
		let result = try decoder.decode(Result.self, from: data)
		return result
	}
	
	func request<Result: Decodable>(_ method: HTTPMethod, url: URL, parameters: [String: String], authorization: AuthorizationType?) async throws -> Result {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(parameters), authorization: \(String(describing: authorization))")
		return try await _request(method, url: url, parameters: parameters, body: nil, authorization: authorization)
	}
	
	func request<Body: Encodable, Result: Decodable>(_ method: HTTPMethod, url: URL, parameters: [String: String], body: Body, authorization: AuthorizationType?) async throws -> Result {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(parameters), authorization: \(String(describing: authorization))")
		let bodyData = try encoder.encode(body)
		return try await _request(method, url: url, parameters: parameters, body: bodyData, authorization: authorization)
	}
}
