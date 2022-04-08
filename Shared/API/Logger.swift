//
//  Logger.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 08.04.22.
//

import Foundation
import os.log

extension Logger {
	init(category: String) {
		self.init(subsystem: "de.melgu.NebulaSwift", category: category)
	}
}
