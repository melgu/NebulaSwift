//
//  API+Categories.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 09.05.22.
//

import Foundation

// MARK: - Info

struct Category: Decodable {
	let id: String
//	let type: TypeEnum
	let slug: String
	let title: String
	let assets: Assets
}
extension Category: Identifiable {}
extension Category: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(slug)
	}
}

extension Category {
	struct Assets: Equatable, Decodable {
		let avatar: String
		let avatarBigDark: String
		let avatarBigLight: String
		
		enum CodingKeys: String, CodingKey {
			case avatar
			case avatarBigDark = "avatar-big-dark"
			case avatarBigLight = "avatar-big-light"
		}
	}
	
//	enum TypeEnum {
//		case category
//	}
}

extension API {
	func allCategories(offset: Int, pageSize: Int = 24) async throws -> [Category] {
		let url = try URL(string: "https://content.watchnebula.com/video/categories/?offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Category> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `allCategories(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allCategories(page: Int, pageSize: Int = 24) async throws -> [Category] {
		try await allCategories(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func videos(for category: Category, offset: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = try URL(string: "https://content.watchnebula.com/video/?category=\(category.slug)&offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `videos(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	func videos(for category: Category, page: Int, pageSize: Int = 24) async throws -> [Video] {
		try await videos(for: category, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func channels(for category: Category, offset: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = try URL(string: "https://content.watchnebula.com/video/channels/?category=\(category.slug)&offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `channels(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	func channels(for category: Category, page: Int, pageSize: Int = 24) async throws -> [Channel] {
		try await channels(for: category, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
}
