//
//  VideoProgress.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.22.
//

import SwiftUI

struct WatchTimeProgressViewStyle: ProgressViewStyle {
	static let lineWidth: CGFloat = 8
	static let defaultFraction: Double = 0
	
	func makeBody(configuration: Configuration) -> some View {
		VStack {
			configuration.label
			progressView(for: configuration.fractionCompleted ?? Self.defaultFraction)
			configuration.currentValueLabel?
				.font(.caption)
		}
	}
	
	func progressView(for fraction: Double) -> some View {
		GeometryReader { proxy in
			ZStack(alignment: .leading) {
				Rectangle()
					.foregroundColor(.secondary)
				Rectangle()
					.foregroundColor(.accentColor)
					.cornerRadius(100)
					.offset(x: -proxy.size.width + proxy.size.width * fraction, y: 0)
			}
		}
		.cornerRadius(100)
		.frame(height: Self.lineWidth)
	}
}

extension ProgressViewStyle where Self == WatchTimeProgressViewStyle {
	static var watchTime: Self { .init() }
}

struct VideoProgress_Previews: PreviewProvider {
	static var previews: some View {
		VStack {
			Group {
				ProgressView("Demo")
				Divider()
				ProgressView(value: 0.5) {
					Text("Demo")
				}  currentValueLabel: {
					Text("Current Value")
				}
			}
			Divider()
			Group {
				ProgressView(value: 0)
				ProgressView(value: 0.004)
				ProgressView(value: 0.3)
				ProgressView(value: 0.5)
				ProgressView(value: 0.7)
				ProgressView(value: 1)
			}
		}
		.progressViewStyle(.watchTime)
	}
}
