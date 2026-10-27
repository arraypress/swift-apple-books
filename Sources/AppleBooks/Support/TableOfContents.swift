//
//  TableOfContents.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  An EPUB's table of contents, in order, as file and title: `toc.ncx` (each navPoint's
//  `navLabel/text` and `content src`) or an EPUB 3 `nav` document (each
//  link in the `toc` nav). Order is kept: a file's first title names it. Pure.
//

import Foundation

enum TableOfContents {

    /// `toc.ncx`'s entries, in order.
    static func ncx(_ data: Data) -> [TOCEntry] {
        let reader = NCXReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.entries
    }

    /// An EPUB 3 nav document's entries, in order.
    static func nav(_ data: Data) -> [TOCEntry] {
        let reader = NavReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.entries
    }
}

/// Reads `toc.ncx`: each navPoint's label, then its source.
final class NCXReader: NSObject, XMLParserDelegate {
    private(set) var entries: [TOCEntry] = []
    private var label = ""
    private var inText = false

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        switch name {
        case "navLabel": label = ""
        case "text": inText = true
        case "content":
            let title = label.trimmingCharacters(in: .whitespacesAndNewlines)
            if let src = attributes["src"], !title.isEmpty { entries.append(TOCEntry(href: src, title: title)) }
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "text" { inText = false }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { label += string }
    }
}

/// Reads an EPUB 3 nav document: each link inside the `toc` nav.
final class NavReader: NSObject, XMLParserDelegate {
    private(set) var entries: [TOCEntry] = []
    private var inToc = false
    private var depth = 0
    private var href: String?
    private var label = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if name == "nav" {
            if inToc { depth += 1 } else if attributes["epub:type"] == "toc" || attributes["type"] == "toc" { inToc = true; depth = 0 }
        }
        if inToc, name == "a" { href = attributes["href"]; label = "" }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if inToc, name == "a", let href {
            let title = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !title.isEmpty { entries.append(TOCEntry(href: href, title: title)) }
            self.href = nil
        }
        if inToc, name == "nav" { if depth == 0 { inToc = false } else { depth -= 1 } }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if href != nil { label += string }
    }
}
