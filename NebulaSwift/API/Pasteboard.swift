//
//  Pasteboard.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import SwiftUI
import UniformTypeIdentifiers

enum Pasteboard {
	static func copy(string: String) {
		#if canImport(UIKit)
		UIPasteboard.general.string = string
		#else
        NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(string, forType: .string)
		#endif
	}
}
