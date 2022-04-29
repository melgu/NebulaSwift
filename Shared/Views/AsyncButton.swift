//
//  AsyncButton.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 29.04.22.
//

import SwiftUI

struct AsyncButton<Label: View>: View {
	let action: @MainActor @Sendable () async -> Void
	let label: () -> Label
	
	@State private var isRunning = false
	
	var body: some View {
		Button {
			Task {
				isRunning = true
				await action()
				isRunning = false
			}
		} label: {
			label()
		}
		.disabled(isRunning)
	}
}

struct AsyncButton_Previews: PreviewProvider {
    static var previews: some View {
		AsyncButton {
			try? await Task.sleep(nanoseconds: 2_000_000_000)
		} label: {
			Text("Button")
		}
    }
}
