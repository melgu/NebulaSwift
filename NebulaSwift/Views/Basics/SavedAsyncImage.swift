//
//  SavedAsyncImage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import SwiftUI

/// Shows an image saved on the device if there is one, or else loads it like `AsyncImage`.
///
/// `AsyncImage` didn't show saved images without a connection, so they're read from disk directly.
struct SavedAsyncImage<Content: View, Placeholder: View>: View {
	let savedURL: URL?
	let url: URL
	let content: (Image) -> Content
	let placeholder: () -> Placeholder
	
	init(savedURL: URL?, url: URL, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
		self.savedURL = savedURL
		self.url = url
		self.content = content
		self.placeholder = placeholder
	}
	
	var body: some View {
		// An unreadable file loads from the network instead
		if let savedURL, let image = SavedImageCache.image(at: savedURL) {
			content(image)
		} else {
			AsyncImage(url: url, content: content, placeholder: placeholder)
		}
	}
}

/// Keeps the saved images that were read, since views showing them update often, like with every step of a download.
@MainActor
private enum SavedImageCache {
	#if canImport(UIKit)
	private static let cache = NSCache<NSURL, UIImage>()
	#else
	private static let cache = NSCache<NSURL, NSImage>()
	#endif
	
	static func image(at url: URL) -> Image? {
		#if canImport(UIKit)
		guard let image = cache.object(forKey: url as NSURL) ?? UIImage(contentsOfFile: url.path) else { return nil }
		cache.setObject(image, forKey: url as NSURL)
		return Image(uiImage: image)
		#else
		guard let image = cache.object(forKey: url as NSURL) ?? NSImage(contentsOf: url) else { return nil }
		cache.setObject(image, forKey: url as NSURL)
		return Image(nsImage: image)
		#endif
	}
}
