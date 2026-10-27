//
//  Book.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One book in the Books library.
public struct Book: Sendable, Codable, Equatable {
    /// Its identifier: Books' asset id.
    public let id: String
    /// Its title.
    public let title: String
    /// Its author.
    public let author: String?
    /// What Books calls it: `ebook`, `pdf`, `audiobook`… — nil until it is on this Mac.
    public let kind: String?
    /// Its genre.
    public let genre: String?
    /// How far through it is, `0…1`.
    public let progress: Double
    /// Whether it is marked finished.
    public let isFinished: Bool
    /// Whether it is a sample.
    public let isSample: Bool
    /// When it was last opened.
    public let lastOpened: Date?
    /// When it was finished.
    public let finished: Date?
    /// The collections it is in, by title.
    public let collections: [String]
    /// Its file on this Mac, when it is downloaded.
    public let file: URL?

    /// A book.
    public init(id: String, title: String, author: String?, kind: String?, genre: String?, progress: Double, isFinished: Bool,
                isSample: Bool, lastOpened: Date?, finished: Date?, collections: [String], file: URL?) {
        self.id = id
        self.title = title
        self.author = author
        self.kind = kind
        self.genre = genre
        self.progress = progress
        self.isFinished = isFinished
        self.isSample = isSample
        self.lastOpened = lastOpened
        self.finished = finished
        self.collections = collections
        self.file = file
    }
}
