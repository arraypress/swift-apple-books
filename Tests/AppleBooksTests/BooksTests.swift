//
//  BooksTests.swift
//  AppleBooks
//
//  Created by David Sherlock on 2026.
//
//  Books with no Books: synthetic library and annotation stores with the
//  real tables, and a tiny EPUB folder (container, package, table of
//  contents). Every title, passage and note is invented.
//

import Foundation
import SQLite3
import XCTest
@testable import AppleBooks

final class BooksTests: XCTestCase {

    // MARK: - Pure

    func testLocationsGiveTheirChapterAndReadingOrder() {
        let early = "epubcfi(/6/12[chapter-001-xhtml]!/4/2[chapter-1]/4[text]/88/3,:234,:256)"
        let later = "epubcfi(/6/12[chapter-001-xhtml]!/4/2[chapter-1]/4[text]/94/1,:0,:75)"
        let range = "epubcfi(/6/12[chapter-001-xhtml]!/4/2[chapter-1]/4[text]/96,/2/1:0,/3:48)"
        let next = "epubcfi(/6/14[chapter-002-xhtml]!/4/2[chapter-2]/4[text]/16/1,:85,:86)"
        XCTAssertEqual(EPUBLocation.chapterID(early), "chapter-001-xhtml")
        XCTAssertNil(EPUBLocation.chapterID("epubcfi(/6/12!/4/2)"))
        XCTAssertEqual(EPUBLocation.order(early), [6, 12, 4, 2, 4, 88, 3, 234], "the path, then the range's start; names ignored")
        XCTAssertEqual(EPUBLocation.order(range), [6, 12, 4, 2, 4, 96, 2, 1, 0], "a range across elements starts at its first part")
        XCTAssertTrue(EPUBLocation.precedes(early, later))
        XCTAssertTrue(EPUBLocation.precedes(later, range))
        XCTAssertTrue(EPUBLocation.precedes(range, next), "the next chapter comes after")
        XCTAssertFalse(EPUBLocation.precedes(next, early))
    }

    func testStylesAreBooksColours() {
        XCTAssertEqual([1, 2, 3, 4, 5].map { AnnotationStyles.color(style: $0, underline: false) }, [.green, .blue, .yellow, .pink, .purple])
        XCTAssertEqual(AnnotationStyles.color(style: 0, underline: true), .underline)
        XCTAssertEqual(AnnotationStyles.color(style: 3, underline: true), .underline, "the flag wins")
        XCTAssertEqual(AnnotationStyles.color(style: 9, underline: false), .other)
        XCTAssertEqual(AnnotationStyles.kind(type: 2), .highlight)
        XCTAssertEqual(AnnotationStyles.kind(type: 1), .bookmark)
        XCTAssertNil(AnnotationStyles.kind(type: 3), "the reading position is not a reader's mark")
    }

    func testContentsNameChaptersFromNCXOrNav() {
        let ncx = Data("""
            <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>
              <navPoint><navLabel><text>Cover</text></navLabel><content src="cover.xhtml"/></navPoint>
              <navPoint><navLabel><text>The Lighthouse</text></navLabel><content src="ch1.xhtml#start"/>
                <navPoint><navLabel><text>A part of it</text></navLabel><content src="ch1.xhtml#later"/></navPoint></navPoint>
            </navMap></ncx>
            """.utf8)
        XCTAssertEqual(TableOfContents.ncx(ncx), [TOCEntry(href: "cover.xhtml", title: "Cover"), TOCEntry(href: "ch1.xhtml#start", title: "The Lighthouse"),
                                                  TOCEntry(href: "ch1.xhtml#later", title: "A part of it")], "in order, nested points too")
        let nav = Data("""
            <html xmlns:epub="http://www.idpf.org/2007/ops"><body>
              <nav epub:type="landmarks"><ol><li><a href="ch1.xhtml">Not this</a></li></ol></nav>
              <nav epub:type="toc"><ol><li><a href="ch1.xhtml">The
                Lighthouse</a></li><li><a href="ch2.xhtml">Low Tide</a></li></ol></nav>
            </body></html>
            """.utf8)
        XCTAssertEqual(TableOfContents.nav(nav), [TOCEntry(href: "ch1.xhtml", title: "The Lighthouse"), TOCEntry(href: "ch2.xhtml", title: "Low Tide")],
                       "only the toc nav; whitespace folded")
        let items = [["id": "c1", "href": "ch1.xhtml"], ["id": "c2", "href": "ch2.xhtml"]]
        XCTAssertEqual(EPUBContents.names(items: items, titles: [TOCEntry(href: "ch1.xhtml#start", title: "The Lighthouse"),
                                                                 TOCEntry(href: "ch1.xhtml#later", title: "A part of it")]),
                       ["c1": "The Lighthouse"], "a file is named by its first title; fragments ignored")
    }

    // MARK: - A synthetic library

    var folder: URL!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("books-\(UUID().uuidString)")
        for sub in ["BKLibrary", "AEAnnotation", "Book.epub/META-INF", "Book.epub/OEBPS"] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    func run(_ file: URL, _ statements: [String]) {
        var db: OpaquePointer?
        sqlite3_open(file.path, &db)
        defer { sqlite3_close(db) }
        for sql in statements { XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql) }
    }

    func makeStore() throws -> BooksStore {
        let epub = folder.appendingPathComponent("Book.epub")
        try Data(#"<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>"#.utf8)
            .write(to: epub.appendingPathComponent("META-INF/container.xml"))
        try Data("""
            <package><manifest><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="ch-1" href="ch1.xhtml" media-type="application/xhtml+xml"/><item id="ch-2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
            </manifest></package>
            """.utf8).write(to: epub.appendingPathComponent("OEBPS/content.opf"))
        try Data("""
            <ncx><navMap><navPoint><navLabel><text>The Lighthouse</text></navLabel><content src="ch1.xhtml"/></navPoint>
            <navPoint><navLabel><text>Low Tide</text></navLabel><content src="ch2.xhtml"/></navPoint></navMap></ncx>
            """.utf8).write(to: epub.appendingPathComponent("OEBPS/toc.ncx"))
        run(folder.appendingPathComponent("BKLibrary/BKLibrary-1.sqlite"), [
            "CREATE TABLE ZBKLIBRARYASSET (Z_PK INTEGER PRIMARY KEY, ZASSETID TEXT, ZTITLE TEXT, ZAUTHOR TEXT, ZKIND TEXT, ZGENRE TEXT, ZREADINGPROGRESS REAL, ZISFINISHED INTEGER, ZISSAMPLE INTEGER, ZLASTOPENDATE REAL, ZDATEFINISHED REAL, ZPATH TEXT, ZCONTENTTYPE INTEGER, ZISHIDDEN INTEGER, ZSORTTITLE TEXT, ZSTATE INTEGER, ZSERIESCONTAINER INTEGER)",
            "CREATE TABLE ZBKCOLLECTION (Z_PK INTEGER PRIMARY KEY, ZCOLLECTIONID TEXT, ZTITLE TEXT, ZDELETEDFLAG INTEGER, ZHIDDEN INTEGER)",
            "CREATE TABLE ZBKCOLLECTIONMEMBER (Z_PK INTEGER PRIMARY KEY, ZASSET INTEGER, ZCOLLECTION INTEGER)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (1, '100', 'The Keeper', 'Ada Moss', 'ebook', 'Fiction', 0.25, 0, 0, 800000000, NULL, '\(epub.path)', 1, 0, 'keeper', 1, 3)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (2, '200', 'Salt Roads', 'Ben Hale', NULL, NULL, 1.0, 1, 0, 790000000, 795000000, NULL, 1, 0, 'salt', 1, NULL)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (4, '400', 'The Keeper Returns', 'Ada Moss', NULL, NULL, 0, 0, 0, 805000000, NULL, NULL, 1, 0, 'keeper2', 5, 3)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (3, '300', 'Coast Trilogy', 'Ada Moss', NULL, NULL, 0, 0, 0, 810000000, NULL, NULL, 5, 0, 'coast', 5, NULL)",
            "INSERT INTO ZBKCOLLECTION VALUES (1, 'All_Collection_ID', 'Library', 0, 0)",
            "INSERT INTO ZBKCOLLECTION VALUES (2, 'Finished_Collection_ID', 'Finished', 0, 0)",
            "INSERT INTO ZBKCOLLECTION VALUES (3, 'X', 'Old shelf', 1, 0)",
            "INSERT INTO ZBKCOLLECTION VALUES (4, 'Books_Collection_ID', 'Books', 0, 0)",
            "INSERT INTO ZBKCOLLECTIONMEMBER VALUES (5, 3, 4)",
            "INSERT INTO ZBKCOLLECTIONMEMBER VALUES (1, 1, 1)", "INSERT INTO ZBKCOLLECTIONMEMBER VALUES (2, 2, 1)",
            "INSERT INTO ZBKCOLLECTIONMEMBER VALUES (3, 2, 2)", "INSERT INTO ZBKCOLLECTIONMEMBER VALUES (4, 2, 3)",
        ])
        run(folder.appendingPathComponent("AEAnnotation/AEAnnotation_local.sqlite"), [
            "CREATE TABLE ZAEANNOTATION (Z_PK INTEGER PRIMARY KEY, ZANNOTATIONUUID TEXT, ZANNOTATIONASSETID TEXT, ZANNOTATIONTYPE INTEGER, ZANNOTATIONSTYLE INTEGER, ZANNOTATIONISUNDERLINE INTEGER, ZANNOTATIONSELECTEDTEXT TEXT, ZANNOTATIONREPRESENTATIVETEXT TEXT, ZANNOTATIONNOTE TEXT, ZANNOTATIONLOCATION TEXT, ZANNOTATIONCREATIONDATE REAL, ZANNOTATIONMODIFICATIONDATE REAL, ZANNOTATIONDELETED INTEGER)",
            "INSERT INTO ZAEANNOTATION VALUES (1, 'a', '100', 2, 4, 0, 'the tide came in', 'And then the tide came in.', 'Lovely line', 'epubcfi(/6/4[ch-2]!/4/2/1,:4,:20)', 800000100, NULL, 0)",
            "INSERT INTO ZAEANNOTATION VALUES (2, 'b', '100', 2, 3, 0, 'the lamp was lit', NULL, NULL, 'epubcfi(/6/2[ch-1]!/4/10/1,:0,:16)', 800000200, NULL, 0)",
            "INSERT INTO ZAEANNOTATION VALUES (3, 'c', '100', 1, 0, 0, NULL, NULL, NULL, 'epubcfi(/6/2[ch-1]!/4/2/1,:0,:1)', 800000300, NULL, 0)",
            "INSERT INTO ZAEANNOTATION VALUES (4, 'd', '100', 2, 1, 0, 'a removed passage', NULL, NULL, 'epubcfi(/6/2[ch-1]!/4/4/1,:0,:5)', 800000400, NULL, 1)",
            "INSERT INTO ZAEANNOTATION VALUES (5, 'e', '100', 3, 0, 0, NULL, NULL, NULL, 'epubcfi(/6/4[ch-2]!/4/2/1,:0,:1)', 800000500, NULL, 0)",
            "INSERT INTO ZAEANNOTATION VALUES (6, 'f', '200', 2, 0, 1, '  salt on the wind  ', NULL, '   ', 'epubcfi(/6/2[x]!/4/2/1,:0,:5)', 790000100, NULL, 0)",
        ])
        return try BooksStore(folder: folder)
    }

    func testBooksAreReadWithTheirCollections() throws {
        let store = try makeStore()
        let books = store.books()
        XCTAssertEqual(books.map(\.title), ["The Keeper", "Salt Roads"],
                       "most recently opened first; a series row and the series' volumes from the store left out")
        XCTAssertEqual(books[0].collections, ["Books"], "a book in a series is in its series' collections")
        XCTAssertEqual(books[1].collections, ["Finished"], "the whole library and deleted collections are not listed")
        XCTAssertTrue(books[1].isFinished)
        XCTAssertEqual(books[0].progress, 0.25)
        XCTAssertNotNil(books[0].file)
        XCTAssertNil(books[1].file, "not on this Mac")
        XCTAssertEqual(store.collections().map(\.title), ["Library", "Finished", "Books"])
        XCTAssertEqual(BooksStore.merged(["Downloaded", "Books"], ["Books", "Library"]), ["Downloaded", "Books", "Library"])
        XCTAssertEqual(try store.book("keeper").id, "100", "words only one title holds")
        XCTAssertEqual(try store.book("200").title, "Salt Roads")
        XCTAssertThrowsError(try store.book("t"), "words two titles hold")
    }

    func testAnnotationsComeInReadingOrderWithTheirChapters() throws {
        let store = try makeStore()
        let marks = store.annotations(book: "100")
        XCTAssertEqual(marks.map(\.id), ["c", "b", "a"], "reading order; deleted and the reading position left out")
        XCTAssertEqual(marks.map(\.kind), [.bookmark, .highlight, .highlight])
        XCTAssertEqual(marks.map(\.chapter), ["The Lighthouse", "The Lighthouse", "Low Tide"])
        XCTAssertNil(marks[0].color, "a bookmark has no colour")
        XCTAssertEqual(marks[2].color, .pink)
        XCTAssertEqual(marks[2].note, "Lovely line")
        XCTAssertEqual(marks[2].context, "And then the tide came in.")
        XCTAssertEqual(store.annotations(book: "100", includeDeleted: true).count, 4)
    }

    func testSearchReadsPassagesAndNotesAcrossBooks() throws {
        let store = try makeStore()
        XCTAssertEqual(store.search("LOVELY").map(\.id), ["a"], "notes, case ignored")
        XCTAssertEqual(store.search("salt on").map(\.id), ["f"])
        let underlined = try XCTUnwrap(store.annotations(book: "200").first)
        XCTAssertEqual(underlined.color, .underline)
        XCTAssertEqual(underlined.text, "salt on the wind", "trimmed")
        XCTAssertNil(underlined.note, "a blank note is no note")
        XCTAssertNil(underlined.chapter, "a book not on this Mac has no chapter names")
        XCTAssertEqual(store.search(" ").count, 0)
    }

    func testAMissingLibrarySaysSo() {
        let missing = folder.appendingPathComponent("none")
        XCTAssertThrowsError(try BooksStore(folder: missing)) { XCTAssertEqual($0 as? AppleBooksError, .storeNotFound(missing)) }
    }
}
