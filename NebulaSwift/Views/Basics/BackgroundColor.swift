//
//  BackgroundColor.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 06.12.22.
//

import SwiftUI

extension Color {
	static var systemBackground: Self {
		#if os(iOS)
		Self(uiColor: .systemBackground)
		#else
		Self(nsColor: .windowBackgroundColor)
		#endif
	}
}
