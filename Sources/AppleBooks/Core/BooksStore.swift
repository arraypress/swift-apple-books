//
//  BooksStore.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  The Books library and its annotations, read from Books' own stores — not
//  by driving the app. Two Core Data SQLite files in Books' container,
//  opened read-only through swift-sqlite-reader: `BKLibrary/*.sqlite` (the books, ZBKLIBRARYASSET; the
//  collections, ZBKCOLLECTION and its members) and `AEAnnotation/*.sqlite`
//  (highlights, notes and bookmarks, ZAEANNOTATION, joined by asset id).
//  A series is a library row of its own (content type 5) holding the books
//  of it the reader has; the series' other volumes come from the store as
//  rows in state 5, not the reader's. Both are left out, and a book in a
//  series is in its series' collections too (that is where Books shows it).
//  Chapters are named from each downloaded book's table of contents
//  (EPUBContents). The container is protected: the app running this needs
//  Full Disk Access. Nothing is written.
//

import Foundation
import SQLiteReader

/// The Books library, read-only.
///
/// ```swift
/// let store = try BooksStore()
/// for book in store.books() { print(book.title, book.progress) }
/// for mark in store.annotations(book: book.id) { print(mark.chapter ?? "", mark.color ?? .other, mark.text ?? "") }
/// ```
public final class BooksStore {

    /// Where Books keeps its stores.
    public static var defaultLocation: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.iBooksX/Data/Documents")
    }

    private let library: SQLiteReader
    private let notes: SQLiteReader?

    /// Opens both stores, read-only.
    ///
    /// - Parameter folder: The folder holding `BKLibrary/` and `AEAnnotation/`; the live one by default.
    /// - Throws: ``AppleBooksError/storeNotFound(_:)``, ``AppleBooksError/permissionDenied(_:)``
    ///   or ``AppleBooksError/databaseError(_:)``.
    public init(folder: URL = BooksStore.defaultLocation) throws {
        guard let libraryFile = Self.store(in: folder.appendingPathComponent("BKLibrary")) else {
            if FileManager.default.fileExists(atPath: folder.path),
               (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) == nil {
                throw AppleBooksError.permissionDenied(folder)
            }
            throw AppleBooksError.storeNotFound(folder)
        }
        library = try Self.open(libraryFile)
        guard !Self.rows(library, "SELECT count(*) FROM ZBKLIBRARYASSET;").isEmpty else {
            throw AppleBooksError.permissionDenied(libraryFile)
        }
        notes = Self.store(in: folder.appendingPathComponent("AEAnnotation")).flatMap { try? Self.open($0) }
    }

    // MARK: - Books

    /// Every book, most recently opened first.
    public func books() -> [Book] {
        var collections: [Int: [String]] = [:]
        for row in Self.rows(library, """
            SELECT m.ZASSET, c.ZTITLE FROM ZBKCOLLECTIONMEMBER m JOIN ZBKCOLLECTION c ON c.Z_PK = m.ZCOLLECTION
            WHERE COALESCE(c.ZDELETEDFLAG, 0) = 0 AND c.ZCOLLECTIONID != 'All_Collection_ID' ORDER BY c.Z_PK;
            """) {
            if let asset = row[0].int, let title = row[1].string { collections[asset, default: []].append(title) }
        }
        return Self.rows(library, """
            SELECT Z_PK, ZASSETID, ZTITLE, ZAUTHOR, ZKIND, ZGENRE, ZREADINGPROGRESS, ZISFINISHED, ZISSAMPLE, ZLASTOPENDATE,
                   ZDATEFINISHED, ZPATH, ZSERIESCONTAINER FROM ZBKLIBRARYASSET
            WHERE COALESCE(ZCONTENTTYPE, 1) != 5 AND COALESCE(ZSTATE, 1) != 5 AND COALESCE(ZISHIDDEN, 0) = 0
            ORDER BY ZLASTOPENDATE DESC, ZSORTTITLE;
            """).compactMap { row -> Book? in
            guard let pk = row[0].int, let id = row[1].string else { return nil }
            let file = row[11].string.map { URL(fileURLWithPath: $0) }.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            return Book(id: id, title: row[2].string ?? "Untitled", author: row[3].string, kind: row[4].string,
                        genre: row[5].string, progress: row[6].double ?? 0, isFinished: row[7].bool ?? false,
                        isSample: row[8].bool ?? false, lastOpened: Self.date(row[9]), finished: Self.date(row[10]),
                        collections: Self.merged(collections[pk] ?? [], row[12].int.flatMap { collections[$0] } ?? []), file: file)
        }
    }

    /// A book by its id, its title (ignoring case), or words only one title holds.
    public func book(_ reference: String) throws -> Book {
        let all = books(), wanted = reference.trimmingCharacters(in: .whitespaces)
        if let exact = all.first(where: { $0.id == wanted || $0.title.caseInsensitiveCompare(wanted) == .orderedSame }) { return exact }
        let partial = all.filter { $0.title.range(of: wanted, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        guard partial.count == 1, let only = partial.first, !wanted.isEmpty else { throw AppleBooksError.bookNotFound(reference) }
        return only
    }

    /// The collections, Books' own first.
    public func collections() -> [BookCollection] {
        Self.rows(library, """
            SELECT c.ZCOLLECTIONID, c.ZTITLE, (SELECT count(*) FROM ZBKCOLLECTIONMEMBER m WHERE m.ZCOLLECTION = c.Z_PK)
            FROM ZBKCOLLECTION c WHERE COALESCE(c.ZDELETEDFLAG, 0) = 0 AND COALESCE(c.ZHIDDEN, 0) = 0 ORDER BY c.Z_PK;
            """).compactMap { row in
            guard let id = row[0].string, let title = row[1].string else { return nil }
            return BookCollection(id: id, title: title, count: row[2].int ?? 0)
        }
    }

    // MARK: - Annotations

    /// Highlights, notes and bookmarks — of one book or all — in reading order, book by book.
    ///
    /// - Parameters:
    ///   - book: Only this book's, by ``Book/id``.
    ///   - includeDeleted: Include ones removed (Books keeps them for sync).
    public func annotations(book: String? = nil, includeDeleted: Bool = false) -> [BookAnnotation] {
        guard let notes else { return [] }
        var clauses = ["1"]
        if !includeDeleted { clauses.append("COALESCE(ZANNOTATIONDELETED, 0) = 0") }
        if let book { clauses.append("ZANNOTATIONASSETID = '\(book.replacingOccurrences(of: "'", with: "''"))'") }
        let files = Dictionary(books().map { ($0.id, $0.file) }, uniquingKeysWith: { first, _ in first })
        var chapters: [String: [String: String]] = [:]
        let found = Self.rows(notes, """
            SELECT ZANNOTATIONUUID, ZANNOTATIONASSETID, ZANNOTATIONTYPE, ZANNOTATIONSTYLE, ZANNOTATIONISUNDERLINE,
                   ZANNOTATIONSELECTEDTEXT, ZANNOTATIONREPRESENTATIVETEXT, ZANNOTATIONNOTE, ZANNOTATIONLOCATION,
                   ZANNOTATIONCREATIONDATE, ZANNOTATIONMODIFICATIONDATE, ZANNOTATIONDELETED, Z_PK
            FROM ZAEANNOTATION WHERE \(clauses.joined(separator: " AND "));
            """).compactMap { row -> BookAnnotation? in
            guard let asset = row[1].string, let kind = AnnotationStyles.kind(type: row[2].int ?? -1) else { return nil }
            let location = row[8].string
            if chapters[asset] == nil { chapters[asset] = (files[asset] ?? nil).map(EPUBContents.chapters) ?? [:] }
            let chapter = location.flatMap(EPUBLocation.chapterID).flatMap { chapters[asset]?[$0] }
            return BookAnnotation(
                id: row[0].string ?? String(row[12].int ?? 0), book: asset, kind: kind,
                color: kind == .highlight ? AnnotationStyles.color(style: row[3].int ?? 0, underline: row[4].bool ?? false) : nil,
                text: Self.words(row[5]), context: Self.words(row[6]), note: Self.words(row[7]), chapter: chapter, location: location,
                created: Self.date(row[9]), modified: Self.date(row[10]), isDeleted: row[11].bool ?? false)
        }
        return found.sorted { a, b in
            a.book != b.book ? a.book < b.book : EPUBLocation.precedes(a.location, b.location)
        }
    }

    /// Highlights whose passage or note holds `text`, ignoring case and accents.
    public func search(_ text: String) -> [BookAnnotation] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return annotations().filter { mark in
            [mark.text, mark.note].compactMap { $0 }.contains { $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    // MARK: - Opening

    /// The store file in a folder: its one `.sqlite`.
    static func store(in folder: URL) -> URL? {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "sqlite" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.first
    }

    /// A store opened read-only.
    static func open(_ url: URL) throws -> SQLiteReader {
        do { return try SQLiteReader(path: url, opening: .readOnly) } catch { throw AppleBooksError(error, store: url) }
    }

    /// Every row `sql` returns; none when it cannot run — the queries here are fixed text.
    static func rows(_ store: SQLiteReader, _ sql: String) -> [SQLiteRow] {
        (try? store.rows(sql)) ?? []
    }

    /// A Core Data date column: seconds since 2001, any value (this library's
    /// own rule, not `appleDate`, which reads 0 as "never").
    static func date(_ value: SQLiteValue) -> Date? {
        value.double.map(Date.init(timeIntervalSinceReferenceDate:))
    }

    /// A book's own collections, then its series' it is not already in.
    static func merged(_ own: [String], _ series: [String]) -> [String] {
        own + series.filter { !own.contains($0) }
    }

    /// Text trimmed, or nil when there is none.
    static func words(_ value: SQLiteValue) -> String? {
        guard let text = value.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
