//
//  RefreshableScrollView.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 27.03.22.
//

import SwiftUI
import SwiftUIPullToRefresh

public struct ScrollView<Content: View>: View {
	private let axes: Axis.Set
	private let showsIndicators: Bool
	private let content: Content
	
	@Environment(\.refresh) private var refresh
	
	public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
		self.axes = axes
		self.showsIndicators = showsIndicators
		self.content = content()
	}
	
	public var body: some View {
		if let refresh = refresh {
			RefreshableScrollView(
				action: { await refresh() },
				progress: { state in
					switch state {
					case .loading, .primed: ProgressView()
					case .waiting: EmptyView()
					}
				},
				content: { content }
			)
		} else {
			SwiftUI.ScrollView(axes, showsIndicators: showsIndicators) {
				content
			}
		}
	}
}

//extension ScrollView {
//	public func refreshable(action: @MainActor @escaping @Sendable () async -> Void) -> some View {
//		RefreshableScrollView(
//			action: action,
//			progress: { state in
//				switch state {
//				case .loading, .primed: ProgressView()
//				case .waiting: EmptyView()
//				}
//			},
//			content: { content }
//		)
//	}
//}

struct RefreshableScrollView_Previews: PreviewProvider {
    static var previews: some View {
		ScrollView {
			Text("A")
			Text("B")
			Text("C")
		}
		.refreshable {
			do {
				try await Task.sleep(nanoseconds: 2_000_000_000)
			} catch {
				
			}
		}
    }
}
