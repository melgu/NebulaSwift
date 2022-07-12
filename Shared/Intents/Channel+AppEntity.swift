//
//  Channel+AppEntity.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 12.07.22.
//

import Foundation
import AppIntents

extension Channel: AppEntity {
	static var defaultQuery = ChannelQuery()
	
	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		.init(name: "Channel")
	}
	
	var displayRepresentation: DisplayRepresentation {
		.init(title: "\(title)")
	}
}
