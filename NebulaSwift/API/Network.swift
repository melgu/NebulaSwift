//
//  Network.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 20.10.21.
//

import Foundation

enum APIError: LocalizedError {
	/// `message` is the reason the server gave, if any.
	case invalidServerResponse(errorCode: Int, message: String?)
	case networkIssues
	case requestTimedOut(url: URL?)
	case missingToken
	case missingBearer
	case missingEngagement
}

extension APIError {
	var errorDescription: String? {
		switch self {
		case .invalidServerResponse(let errorCode, let message):
			// The server's own reason, like wrong login details, says more than the code
			return message ?? String(localized: "Invalid server response. Error code \(errorCode)")
		case .networkIssues:
			return String(localized: "Network issues")
		case .requestTimedOut(let url):
			return String(localized: "Request timed out. URL: \(url?.absoluteString ?? "nil")")
		case .missingToken, .missingBearer:
			return String(localized: "Missing authorization")
		case .missingEngagement:
			return String(localized: "Missing engagement information")
		}
	}
	
	/// Whether the server rejected the request's authorization, which it does with either 401 or 403.
	var isUnauthorized: Bool {
		guard case .invalidServerResponse(let code, _) = self else { return false }
		return code == 401 || code == 403
	}
}

extension API {
	enum AuthorizationType {
		case token
		case bearer
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
			guard let token else { throw APIError.missingToken }
			request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
		case .bearer:
			guard let bearer else { throw APIError.missingBearer }
			request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
		case .none:
			break
		}
	}
	
	private func execute(request: URLRequest) async throws -> Data {
		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let httpResponse = response as? HTTPURLResponse else {
				throw APIError.networkIssues
			}
			guard httpResponse.statusCode == 200 else {
				throw APIError.invalidServerResponse(errorCode: httpResponse.statusCode, message: Self.serverMessage(in: data))
			}
			return data
		} catch URLError.timedOut {
			throw APIError.requestTimedOut(url: request.url)
		}
	}
	
	/// The reason in an error response, as Django REST framework writes it: a `detail` text, or lists of messages
	/// per field, with `non_field_errors` for the request as a whole.
	private static func serverMessage(in data: Data) -> String? {
		guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
		if let detail = object["detail"] as? String {
			return detail
		}
		let messages = object.keys.sorted().flatMap { object[$0] as? [String] ?? [] }
		return messages.isEmpty ? nil : messages.joined(separator: "\n")
	}
	
	private func _request(_ method: HTTPMethod, url: URL, headerFields: [String: String], body: Data?, authorization: AuthorizationType?) async throws -> Data {
		var request = URLRequest(url: url)
		
		request.httpMethod = method.rawValue
		if let body = body {
			request.httpBody = body
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		}
		request.cachePolicy = .useProtocolCachePolicy
		request.allHTTPHeaderFields = headerFields
		
		try setAuthorization(type: authorization, for: &request)
		
		do {
			return try await execute(request: request)
		} catch let error as APIError {
			if error.isUnauthorized {
				switch authorization {
				case .token:
					logout()
					throw error
				case .bearer:
					do {
						try await refreshAuthorization()
					} catch let refreshError as APIError {
						// A refresh rejected with 401 or 403 already logs out via the
						// `.token` case above. Only a completely missing token
						// needs handling here; network issues must not log out.
						if case .missingToken = refreshError {
							logout()
						}
						throw refreshError
					}
				case .none:
					throw error
				}
				try setAuthorization(type: authorization, for: &request)
				do {
					return try await execute(request: request)
				} catch let retryError as APIError {
					if retryError.isUnauthorized {
						logout()
					}
					throw retryError
				}
			} else {
				throw error
			}
		}
	}
	
	private func _request<Result: Decodable>(_ method: HTTPMethod, url: URL, headerFields: [String: String], body: Data?, authorization: AuthorizationType?) async throws -> Result {
		let data = try await _request(method, url: url, headerFields: headerFields, body: body, authorization: authorization)
		let result = try decoder.decode(Result.self, from: data)
		return result
	}
	
	func request<Result: Decodable>(_ method: HTTPMethod, url: URL, headerFields: [String: String] = [:], authorization: AuthorizationType?) async throws -> Result {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(headerFields), authorization: \(String(describing: authorization))")
		return try await _request(method, url: url, headerFields: headerFields, body: nil, authorization: authorization)
	}
	
	func request<Body: Encodable, Result: Decodable>(_ method: HTTPMethod, url: URL, headerFields: [String: String] = [:], body: Body, authorization: AuthorizationType?) async throws -> Result {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(headerFields), body: \(String(describing: body)), authorization: \(String(describing: authorization))")
		let bodyData = try encoder.encode(body)
		return try await _request(method, url: url, headerFields: headerFields, body: bodyData, authorization: authorization)
	}
	
	func request(_ method: HTTPMethod, url: URL, headerFields: [String: String] = [:], authorization: AuthorizationType?) async throws {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(headerFields), authorization: \(String(describing: authorization))")
		_ = try await _request(method, url: url, headerFields: headerFields, body: nil, authorization: authorization)
	}
	
	func request<Body: Encodable>(_ method: HTTPMethod, url: URL, headerFields: [String: String] = [:], body: Body, authorization: AuthorizationType?) async throws {
		logger.debug("Request: method: \(method.rawValue), url: \(url), parameters: \(headerFields), body: \(String(describing: body)), authorization: \(String(describing: authorization))")
		let bodyData = try encoder.encode(body)
		_ = try await _request(method, url: url, headerFields: headerFields, body: bodyData, authorization: authorization)
	}
}
