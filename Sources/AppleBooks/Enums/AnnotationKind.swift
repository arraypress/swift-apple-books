//
//  AnnotationKind.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What an annotation is.
public enum AnnotationKind: String, Sendable, Codable, CaseIterable, Hashable {
    /// A marked passage, with or without a note (type 2).
    case highlight
    /// A bookmarked page (type 1).
    case bookmark
}
