//
//  EPUBLocation.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  Books places an annotation with an EPUB CFI:
//  `epubcfi(/6/12[chapter-001-xhtml]!/4/2[chapter-1]/94/1,:175,:278)` — the
//  spine step (`/6/12`) names the chapter's manifest id in brackets, then
//  the path inside it, then the range. This reads the chapter's id and an
//  order to sort by: every number, step by step, of the path and the
//  range's start. Pure.
//

import Foundation

enum EPUBLocation {

    /// The manifest id of the chapter: the first bracketed name.
    static func chapterID(_ cfi: String) -> String? {
        guard let open = cfi.firstIndex(of: "["), let close = cfi[open...].firstIndex(of: "]") else { return nil }
        let id = String(cfi[cfi.index(after: open)..<close])
        return id.isEmpty ? nil : id
    }

    /// The numbers to sort by: the path, then the range's start.
    static func order(_ cfi: String) -> [Int] {
        var body = cfi
        if body.hasPrefix("epubcfi(") { body = String(body.dropFirst(8)) }
        if body.hasSuffix(")") { body = String(body.dropLast()) }
        body = body.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
        let parts = body.split(separator: ",", omittingEmptySubsequences: false)
        let start = parts.count >= 2 ? String(parts[0]) + String(parts[1]) : body
        return start.split { !$0.isNumber }.compactMap { Int($0) }
    }

    /// Whether `a` comes before `b`, number by number.
    static func precedes(_ a: String?, _ b: String?) -> Bool {
        let x = a.map(order) ?? [], y = b.map(order) ?? []
        return x.lexicographicallyPrecedes(y)
    }
}
