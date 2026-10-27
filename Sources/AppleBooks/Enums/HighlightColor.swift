//
//  HighlightColor.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a passage is marked: Books' highlight colours, and underline.
public enum HighlightColor: String, Sendable, Codable, CaseIterable, Hashable {
    /// Green (style 1).
    case green
    /// Blue (style 2).
    case blue
    /// Yellow (style 3).
    case yellow
    /// Pink (style 4).
    case pink
    /// Purple (style 5).
    case purple
    /// Underlined rather than highlighted.
    case underline
    /// A style this does not know yet.
    case other
}
