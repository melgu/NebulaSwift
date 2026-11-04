//
//  Keychain.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.11.26.
//

import Foundation
import Security

struct KeychainError: Error, CustomStringConvertible {
	let status: OSStatus
	
	var description: String {
		SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
	}
}

/// Generic password items of the app, in the login keychain on macOS.
/// Doesn't use the data protection keychain there, as that needs a provisioning profile.
enum Keychain {
	private static let service = Bundle.main.bundleIdentifier ?? "de.melgu.NebulaSwift"
	
	private static func baseQuery(account: String) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account
		]
	}
	
	/// Returns nil if the item doesn't exist.
	static func load(account: String) throws -> String? {
		var query = baseQuery(account: account)
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		
		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		if status == errSecItemNotFound {
			return nil
		}
		guard status == errSecSuccess else {
			throw KeychainError(status: status)
		}
		return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
	}
	
	static func save(_ value: String, account: String) throws {
		let data = Data(value.utf8)
		let query = baseQuery(account: account)
		let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
		if status == errSecItemNotFound {
			var item = query
			item[kSecValueData as String] = data
			// Background downloads and progress updates may need the bearer while the device is locked
			item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
			let addStatus = SecItemAdd(item as CFDictionary, nil)
			guard addStatus == errSecSuccess else {
				throw KeychainError(status: addStatus)
			}
		} else if status != errSecSuccess {
			throw KeychainError(status: status)
		}
	}
	
	static func delete(account: String) throws {
		let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError(status: status)
		}
	}
}
