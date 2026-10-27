//
//  AnnotationStyles.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  Books' annotation numbers, measured on a book annotated for the purpose
//  (each highlight's note named the colour picked): type 2 a highlight
//  (with its note, if any), 1 a bookmark, 3 the reading position (left
//  out: the library's progress says it); style 1 green, 2 blue, 3 yellow,
//  4 pink, 5 purple, and an underline is style 0 with its own flag. Pure.
//

import Foundation

enum AnnotationStyles {

    /// The kind for a type, or nil for one that is not an annotation a reader made.
    static func kind(type: Int) -> AnnotationKind? {
        switch type {
        case 2: return .highlight
        case 1: return .bookmark
        default: return nil
        }
    }

    /// The colour for a style and the underline flag.
    static func color(style: Int, underline: Bool) -> HighlightColor {
        if underline { return .underline }
        switch style {
        case 1: return .green
        case 2: return .blue
        case 3: return .yellow
        case 4: return .pink
        case 5: return .purple
        default: return .other
        }
    }
}
