//
//  BookAnnotation.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A highlight, a note on one, or a bookmark.
public struct BookAnnotation: Sendable, Codable, Equatable {
    /// Its identifier.
    public let id: String
    /// The book it is in, by ``Book/id``.
    public let book: String
    /// What it is.
    public let kind: AnnotationKind
    /// How the passage is marked; nil for a bookmark.
    public let color: HighlightColor?
    /// The passage marked.
    public let text: String?
    /// The words around it, as Books keeps them.
    public let context: String?
    /// The note written on it.
    public let note: String?
    /// The chapter, from the book's table of contents, when the book is on this Mac.
    public let chapter: String?
    /// Where it is: an EPUB CFI.
    public let location: String?
    /// When it was made.
    public let created: Date?
    /// When it was last changed.
    public let modified: Date?
    /// Whether it was removed (kept by Books for sync).
    public let isDeleted: Bool

    /// An annotation.
    public init(id: String, book: String, kind: AnnotationKind, color: HighlightColor?, text: String?, context: String?, note: String?,
                chapter: String?, location: String?, created: Date?, modified: Date?, isDeleted: Bool) {
        self.id = id
        self.book = book
        self.kind = kind
        self.color = color
        self.text = text
        self.context = context
        self.note = note
        self.chapter = chapter
        self.location = location
        self.created = created
        self.modified = modified
        self.isDeleted = isDeleted
    }
}
