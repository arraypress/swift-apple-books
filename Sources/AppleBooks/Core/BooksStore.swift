//
//  BooksStore.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  The Books library and its annotations, read from Books' own stores — not
//  by driving the app. Two Core Data SQLite files in Books' container,
//  opened read-only: `BKLibrary/*.sqlite` (the books, ZBKLIBRARYASSET; the
//  collections, ZBKCOLLECTION and its members) and `AEAnnotation/*.sqlite`
//  (highlights, notes and bookmarks, ZAEANNOTATION, joined by asset id).
//  A series is a library row of its own (content type 5) and is left out.
//  Chapters are named from each downloaded book's table of contents
//  (EPUBContents). The container is protected: the app running this needs
//  Full Disk Access. Nothing is written.
//

import Foundation
import SQLite3

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

    private let library: OpaquePointer
    private let notes: OpaquePointer?

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
        guard !SQLiteRows.rows(library, "SELECT count(*) FROM ZBKLIBRARYASSET;").isEmpty else {
            sqlite3_close(library)
            throw AppleBooksError.permissionDenied(libraryFile)
        }
        notes = Self.store(in: folder.appendingPathComponent("AEAnnotation")).flatMap { try? Self.open($0) }
    }

    deinit {
        sqlite3_close(library)
        if let notes { sqlite3_close(notes) }
    }

    // MARK: - Books

    /// Every book, most recently opened first.
    public func books() -> [Book] {
        var collections: [Int64: [String]] = [:]
        for row in SQLiteRows.rows(library, """
            SELECT m.ZASSET, c.ZTITLE FROM ZBKCOLLECTIONMEMBER m JOIN ZBKCOLLECTION c ON c.Z_PK = m.ZCOLLECTION
            WHERE COALESCE(c.ZDELETEDFLAG, 0) = 0 AND c.ZCOLLECTIONID != 'All_Collection_ID' ORDER BY c.Z_PK;
            """) {
            if let asset = row[0] as? Int64, let title = row[1] as? String { collections[asset, default: []].append(title) }
        }
        return SQLiteRows.rows(library, """
            SELECT Z_PK, ZASSETID, ZTITLE, ZAUTHOR, ZKIND, ZGENRE, ZREADINGPROGRESS, ZISFINISHED, ZISSAMPLE, ZLASTOPENDATE,
                   ZDATEFINISHED, ZPATH FROM ZBKLIBRARYASSET
            WHERE COALESCE(ZCONTENTTYPE, 1) != 5 AND COALESCE(ZISHIDDEN, 0) = 0
            ORDER BY ZLASTOPENDATE DESC, ZSORTTITLE;
            """).compactMap { row -> Book? in
            guard let pk = row[0] as? Int64, let id = row[1] as? String else { return nil }
            let file = (row[11] as? String).map { URL(fileURLWithPath: $0) }.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            return Book(id: id, title: row[2] as? String ?? "Untitled", author: row[3] as? String, kind: row[4] as? String,
                        genre: row[5] as? String, progress: row[6] as? Double ?? 0, isFinished: (row[7] as? Int64 ?? 0) != 0,
                        isSample: (row[8] as? Int64 ?? 0) != 0, lastOpened: SQLiteRows.date(row[9]), finished: SQLiteRows.date(row[10]),
                        collections: collections[pk] ?? [], file: file)
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
        SQLiteRows.rows(library, """
            SELECT c.ZCOLLECTIONID, c.ZTITLE, (SELECT count(*) FROM ZBKCOLLECTIONMEMBER m WHERE m.ZCOLLECTION = c.Z_PK)
            FROM ZBKCOLLECTION c WHERE COALESCE(c.ZDELETEDFLAG, 0) = 0 AND COALESCE(c.ZHIDDEN, 0) = 0 ORDER BY c.Z_PK;
            """).compactMap { row in
            guard let id = row[0] as? String, let title = row[1] as? String else { return nil }
            return BookCollection(id: id, title: title, count: Int(row[2] as? Int64 ?? 0))
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
        let found = SQLiteRows.rows(notes, """
            SELECT ZANNOTATIONUUID, ZANNOTATIONASSETID, ZANNOTATIONTYPE, ZANNOTATIONSTYLE, ZANNOTATIONISUNDERLINE,
                   ZANNOTATIONSELECTEDTEXT, ZANNOTATIONREPRESENTATIVETEXT, ZANNOTATIONNOTE, ZANNOTATIONLOCATION,
                   ZANNOTATIONCREATIONDATE, ZANNOTATIONMODIFICATIONDATE, ZANNOTATIONDELETED, Z_PK
            FROM ZAEANNOTATION WHERE \(clauses.joined(separator: " AND "));
            """).compactMap { row -> BookAnnotation? in
            guard let asset = row[1] as? String, let kind = AnnotationStyles.kind(type: Int(row[2] as? Int64 ?? -1)) else { return nil }
            let location = row[8] as? String
            if chapters[asset] == nil { chapters[asset] = (files[asset] ?? nil).map(EPUBContents.chapters) ?? [:] }
            let chapter = location.flatMap(EPUBLocation.chapterID).flatMap { chapters[asset]?[$0] }
            return BookAnnotation(
                id: row[0] as? String ?? String(row[12] as? Int64 ?? 0), book: asset, kind: kind,
                color: kind == .highlight ? AnnotationStyles.color(style: Int(row[3] as? Int64 ?? 0), underline: (row[4] as? Int64 ?? 0) != 0) : nil,
                text: Self.words(row[5]), context: Self.words(row[6]), note: Self.words(row[7]), chapter: chapter, location: location,
                created: SQLiteRows.date(row[9]), modified: SQLiteRows.date(row[10]), isDeleted: (row[11] as? Int64 ?? 0) != 0)
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

    static func open(_ url: URL) throws -> OpaquePointer {
        var opened: OpaquePointer?
        guard sqlite3_open_v2("file:\(url.path)?mode=ro", &opened, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open"
            sqlite3_close(opened)
            throw message.lowercased().contains("authoriz") || message.lowercased().contains("permission")
                ? AppleBooksError.permissionDenied(url) : AppleBooksError.databaseError(message)
        }
        return opened
    }

    /// Text trimmed, or nil when there is none.
    static func words(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
