//
//  ListContainer.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import Foundation

struct ListContainer<Content: Decodable>: Decodable {
	let next: String?
	let previous: String?
	let results: [Content]
}
