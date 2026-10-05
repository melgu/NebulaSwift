//
//  DownloadError.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation

enum DownloadError: LocalizedError {
	/// The stream uses features the downloader doesn't handle, like encryption or byte ranges.
	case unsupportedStream
	/// The server refused a request, most likely because the signed stream URL expired.
	case accessDenied
	case invalidServerResponse(statusCode: Int)
	case processingFailed
}

extension DownloadError {
	var errorDescription: String? {
		switch self {
		case .unsupportedStream:
			String(localized: "This video's stream can't be downloaded.")
		case .accessDenied:
			String(localized: "Access to the video was denied.")
		case .invalidServerResponse(let statusCode):
			String(localized: "Invalid server response. Error code \(statusCode)")
		case .processingFailed:
			String(localized: "The downloaded video couldn't be processed.")
		}
	}
}
