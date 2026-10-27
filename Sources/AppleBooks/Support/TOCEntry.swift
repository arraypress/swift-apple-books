//
//  TOCEntry.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One line of a book's table of contents: the file (and fragment) it opens, and its title.
struct TOCEntry: Equatable {
    /// `chapter-001.xhtml` or `chapter-001.xhtml#part`.
    let href: String
    /// What the contents call it.
    let title: String
}
