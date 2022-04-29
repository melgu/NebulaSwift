//
//  ShareSheet.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 26.03.22.
//

import SwiftUI

// MARK: Public Interface

extension View {
	/// Presents a sheet when a binding to a list of items that you provide is non-`nil`.
	///
	/// ```
	/// struct MyView {
	///     @State var itemsToShare: [Any]?
	///     var body: some View {
	///         Label("Share", systemImage: "square.and.arrow.up")
	///             .onTapGesture {
	///                 itemsToShare = ["This text will be shared"]
	///             }
	///             .shareSheet(items: $itemsToShare)
	///     }
	/// }
	/// ```
	///
	/// On iPadOS and macOS the share sheet or picker will be presented at the position of the modified view.
	///
	/// - Parameters:
	///   - items: The items to be shared. When `items` is non-`nil`, the share sheet or picker will be presented.
	///   - onDismiss: The closure to execute when dismissing the sheet or picker.
	public func shareSheet(items: Binding<[Any]?>, onDismiss: @escaping () -> Void = {}) -> some View {
		self.background(ShareSheetPresenter(items: items, onDismiss: onDismiss))
	}
}

/// A control that presents the Share Sheet on iOS and Sharing Picker on macOS.
public struct ShareButton<Label: View>: View {
	private let items: () -> [Any]
	private let onDismiss: () -> Void
	private let label: Label
	
	@State private var shareItems: [Any]?
	
	/// A control that presents the Share Sheet on iOS and Sharing Picker on macOS.
	///
	/// ```
	/// struct MyView: View {
	///     ShareButton(items: [someText, someURL]) {
	///         Text("Share")
	///     }
	/// }
	/// ```
	///
	/// On iPadOS and macOS the share sheet or picker will be presented at the button's position.
	///
	/// - Parameters:
	///   - items: The items to be shared.
	///   - onDismiss: The closure to execute when dismissing the sheet or picker.
	///   - label: A view that describes the purpose of the button.
	public init(items: @autoclosure @escaping () -> [Any], onDismiss: @escaping () -> Void = {}, @ViewBuilder label: () -> Label) {
		self.items = items
		self.onDismiss = onDismiss
		self.label = label()
	}
	
	public var body: some View {
		Button {
			shareItems = items()
		} label: {
			label
		}
		.shareSheet(items: $shareItems, onDismiss: onDismiss)
	}
}

// MARK: - Platform Specifics

#if canImport(UIKit)

fileprivate struct ShareSheetPresenter: UIViewRepresentable {
	@Binding var items: [Any]?
	let onDismiss: () -> Void
	
	func makeUIView(context: Context) -> UIView {
		UIView()
	}
	
	func updateUIView(_ uiView: UIView, context: Context) {
		guard let items = items else { return }

		let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
		activityController.presentationController?.delegate = context.coordinator
		activityController.popoverPresentationController?.sourceView = uiView
		uiView.window?.rootViewController?.present(activityController, animated: true)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(owner: self)
	}

	class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
		private let owner: ShareSheetPresenter

		init(owner: ShareSheetPresenter) {
			self.owner = owner
		}
		
		func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
			presentationController.delegate = nil // Cleanup
			owner.items = nil // Communicate dismiss to SwiftUI
			owner.onDismiss()
		}
	}
}

#else

fileprivate struct ShareSheetPresenter: NSViewRepresentable {
	@Binding var items: [Any]?
	let onDismiss: () -> Void

	func makeNSView(context: Context) -> NSView {
		NSView()
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		guard let items = items else { return }
		
		let picker = NSSharingServicePicker(items: items)
		picker.delegate = context.coordinator
		
		DispatchQueue.main.async {
			// Has to be called async to not block update
			picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(owner: self)
	}

	class Coordinator: NSObject, NSSharingServicePickerDelegate {
		private let owner: ShareSheetPresenter

		init(owner: ShareSheetPresenter) {
			self.owner = owner
		}

		func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
			sharingServicePicker.delegate = nil // Cleanup
			owner.items = nil // Communicate dismiss to SwiftUI
			owner.onDismiss()
		}
	}
}

#endif

// MARK: - Preview

fileprivate struct ShareSheetDemo: View {
	@State private var shareItems: [Any]? = nil
	
	var body: some View {
		VStack {
			ShareButton(items: ["Demo"]) {
				Text("Share Button")
			}
			
			Button {
				shareItems = ["Demo"]
			} label: {
				Text("Share Sheet Modifier")
			}
			.shareSheet(items: $shareItems)
		}
	}
}

struct ShareSheet_Previews: PreviewProvider {
	static var previews: some View {
		ShareSheetDemo()
	}
}
