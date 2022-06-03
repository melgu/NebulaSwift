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

extension Category {
	struct Assets: Decodable {
		let avatar: String
		let avatarBigDark: String
		let avatarBigLight: String
		
		enum CodingKeys: String, CodingKey {
			case avatar, avatarBigDark = "avatar-big-dark", avatarBigLight = "avatar-big-light"
		}
	}
	
//	enum TypeEnum {
//		case category
//	}
}

extension API {
	func allCategories(page: Int, pageSize: Int = 24) async throws -> [Category] {
		let url = URL(string: "https://content.watchnebula.com/video/categories/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Category> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func videos(for category: Category, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/video/?category=\(category.slug)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func channels(for category: Category, page: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/video/channels/?category=\(category)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
}
