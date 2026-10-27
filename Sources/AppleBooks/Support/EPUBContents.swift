//
//  EPUBContents.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  A book's chapter names, from its own files: `META-INF/container.xml`
//  names the package (`content.opf`), whose manifest maps ids to files, and
//  whose table of contents — `toc.ncx`, or an EPUB 3 `nav` document — names
//  each file. A store book's chapters are encrypted, but these files are
//  not (none of a measured book's 57 encrypted files was one). Read once a
//  book. Pure apart from reading the files.
//

import Foundation

enum EPUBContents {

    /// Chapter names by manifest id; empty when the book is not on this Mac or has none.
    static func chapters(in book: URL) -> [String: String] {
        guard let container = try? Data(contentsOf: book.appendingPathComponent("META-INF/container.xml")),
              let package = XMLAttributes.first(in: container, element: "rootfile", attribute: "full-path"),
              let opf = try? Data(contentsOf: book.appendingPathComponent(package)) else { return [:] }
        let base = book.appendingPathComponent(package).deletingLastPathComponent()
        let items = XMLAttributes.all(in: opf, element: "item")
        var titles: [TOCEntry] = []
        if let ncx = items.first(where: { $0["media-type"] == "application/x-dtbncx+xml" })?["href"],
           let data = try? Data(contentsOf: base.appendingPathComponent(ncx)) {
            titles = TableOfContents.ncx(data)
        } else if let nav = items.first(where: { ($0["properties"] ?? "").split(separator: " ").contains("nav") })?["href"],
                  let data = try? Data(contentsOf: base.appendingPathComponent(nav)) {
            titles = TableOfContents.nav(data)
        }
        return names(items: items, titles: titles)
    }

    /// Each manifest id named by the first title its file has in the contents (fragments ignored).
    static func names(items: [[String: String]], titles: [TOCEntry]) -> [String: String] {
        var byFile: [String: String] = [:]
        for entry in titles {
            let file = String(entry.href.split(separator: "#").first ?? "")
            if byFile[file] == nil { byFile[file] = entry.title }
        }
        var found: [String: String] = [:]
        for item in items {
            guard let id = item["id"], let href = item["href"], let title = byFile[href.removingPercentEncoding ?? href] ?? byFile[href] else { continue }
            found[id] = title
        }
        return found
    }
}
