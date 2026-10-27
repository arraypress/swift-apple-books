//
//  XMLAttributes.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  The attributes of every element of a name in an XML document — enough
//  for an EPUB's container and package files. Pure.
//

import Foundation

enum XMLAttributes {

    /// Every `element`'s attributes, in order.
    static func all(in data: Data, element: String) -> [[String: String]] {
        let reader = Reader(element: element)
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.found
    }

    /// The first `element`'s `attribute`.
    static func first(in data: Data, element: String, attribute: String) -> String? {
        all(in: data, element: element).lazy.compactMap { $0[attribute] }.first
    }

    /// Collects one element's attributes.
    final class Reader: NSObject, XMLParserDelegate {
        let element: String
        private(set) var found: [[String: String]] = []

        init(element: String) { self.element = element }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            if name == element { found.append(attributes) }
        }
    }
}
