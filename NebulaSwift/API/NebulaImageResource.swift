//
//  NebulaImageResource.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import Foundation

struct NebulaImageResource: Codable, Equatable {
	let original: URL
	
	init(from decoder: Decoder) throws {
		if let container = try? decoder.container(keyedBy: CodingKeys.self) {
			self.original = try container.decode(URL.self, forKey: .original)
		} else {
			let container = try decoder.singleValueContainer()
			self.original = try container.decode(URL.self)
		}
	}
}

/// An image on Nebula's image host, which resizes on the fly.
struct NebulaImage: Codable, Equatable {
	let src: URL
	let width: Int
	let height: Int
	
	/// The image scaled to the given width.
	subscript(width: Int) -> URL {
		src.appending(queryItems: [URLQueryItem(name: "width", value: String(width))])
	}
}
