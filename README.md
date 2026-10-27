# Swift Apple Books

Read Apple Books from Swift — the library (books, progress, collections) and every highlight,
note and bookmark, with its colour and chapter — from Books' own stores, not by driving the app.

```swift
import AppleBooks

let store = try BooksStore()
for book in store.books() { print(book.title, book.progress, book.collections) }
let keeper = try store.book("keeper")                   // an id, a title, or words only one title holds
for mark in store.annotations(book: keeper.id) {        // reading order
    print(mark.chapter ?? "", mark.color ?? .other, mark.text ?? "", mark.note ?? "")
}
store.search("tide")                                    // passages and notes, every book
```

## Where Books keeps it

Measured on macOS 27 with a book annotated for the purpose — each highlight's note named the
colour picked:

- **Two Core Data stores** in `~/Library/Containers/com.apple.iBooksX/Data/Documents/`:
  `BKLibrary/*.sqlite` (books in `ZBKLIBRARYASSET`, collections in `ZBKCOLLECTION` and its
  members) and `AEAnnotation/*.sqlite` (`ZAEANNOTATION`, joined by asset id). The container is
  protected: the app reading it needs Full Disk Access. Opened read-only.
- **Annotation types**: 2 a highlight (its note in the same row), 1 a bookmark, 3 the reading
  position (left out — the library's progress says it). Removed ones stay, flagged, for sync;
  they are left out unless asked.
- **Colours** by style: 1 green, 2 blue, 3 yellow, 4 pink, 5 purple; an underline is style 0
  with its own flag. Each matched the note written on it.
- **Where** is an EPUB CFI (`epubcfi(/6/12[chapter-001-xhtml]!/4/2/…,:175,:278)`). Annotations
  are sorted by its numbers, path then range start, which is reading order.
- **Chapters** are named from the book's own table of contents: the CFI's first bracketed
  name is a manifest id in `content.opf`, whose file `toc.ncx` (or an EPUB 3 `nav` document)
  titles; a file's first title names it. A store book's chapters are encrypted, but these
  files are not (none of a measured book's 57 encrypted files was one). A book not on this Mac
  has no chapter names.
- **A series** is a library row of its own (content type 5) and is left out of the books.

## Writing

Nothing here writes. Books has no AppleScript dictionary for annotations.

## Tested

7 tests against synthetic stores with the real tables and a tiny EPUB folder — no one's library
is read. Every rule broken on purpose is caught (18 of 18 mutations). Checked by hand on a book
annotated for the test: six colours and an underline, notes, two bookmarks (and a removed
one), chapter names and reading order all read.

## Requirements

macOS 14 or later; Swift 6.2. Full Disk Access for the app reading it.

## License

MIT — see [LICENSE](LICENSE).
