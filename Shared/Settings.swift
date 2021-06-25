//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

class Settings: ObservableObject {
	static let shared = Settings()
	
	@AppStorage(Defaults.token) var token = ""
	@AppStorage(Defaults.bearer) var bearer = ""
	@AppStorage(Defaults.nebulaAuthApi) var nebulaAuthApi = ""
	@AppStorage(Defaults.nebulaContentApi) var nebulaContentApi = ""
	@AppStorage(Defaults.zyneApi) var zyneApi = ""
	
	private init() {}
}
