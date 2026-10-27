//
//  BookCollection.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A collection in the Books library: Want to Read, Finished, or one of the reader's own.
public struct BookCollection: Sendable, Codable, Equatable {
    /// Its identifier: `Finished_Collection_ID` for Books' own, a UUID for the reader's.
    public let id: String
    /// Its title.
    public let title: String
    /// How many books are in it.
    public let count: Int

    /// A collection.
    public init(id: String, title: String, count: Int) {
        self.id = id
        self.title = title
        self.count = count
    }
}
