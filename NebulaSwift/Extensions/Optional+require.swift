//
//  Optional+require.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 06.11.25.
//

import Foundation

extension Optional {
	struct MissingValueError: Error {}
	
	func require() throws(MissingValueError) -> Wrapped {
		guard let self else {
			throw .init()
		}
		return self
	}
}
