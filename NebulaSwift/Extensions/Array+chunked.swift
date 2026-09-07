//
//  Array+chunked.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.09.26.
//

import Foundation

extension Array {
	/// Splits the array into slices of at most `size` elements.
	///
	/// The engagement endpoints only accept a limited number of identifiers per request.
	func chunked(into size: Int) -> [ArraySlice<Element>] {
		stride(from: 0, to: count, by: size).map { self[$0 ..< Swift.min($0 + size, count)] }
	}
}
