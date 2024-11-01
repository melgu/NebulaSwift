//
//  Inop.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 24.07.22.
//

import Foundation

enum Inop: LocalizedError {
	case comingSoon
	
	var errorDescription: String? {
		switch self {
		case .comingSoon:
			return "This functionality is not yet implemented, but will be coming soon."
		}
	}
}
