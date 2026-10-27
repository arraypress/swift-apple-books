//
//  AppleBooksError.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why the Books library could not be read.
public enum AppleBooksError: Error, Sendable, Equatable, LocalizedError {
    /// There is no library: Books has never been opened on this Mac.
    case storeNotFound(URL)
    /// macOS refused it: the app running this needs Full Disk Access.
    case permissionDenied(URL)
    /// SQLite could not read it.
    case databaseError(String)
    /// No book matches, or more than one does.
    case bookNotFound(String)

    /// A sentence for a person.
    public var errorDescription: String? {
        switch self {
        case .storeNotFound: return "no Books library on this Mac — open Books once"
        case .permissionDenied: return "macOS refused the Books library — give the app running this Full Disk Access"
        case .databaseError(let message): return "the Books library could not be read: \(message)"
        case .bookNotFound(let book): return "no single book matches \(book)"
        }
    }
}
