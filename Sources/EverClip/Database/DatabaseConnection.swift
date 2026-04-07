import Foundation
import CSQLite

final class DatabaseConnection {
    private(set) var db: OpaquePointer?

    init(path: String) {
        let rc = sqlite3_open(path, &db)
        if rc != SQLITE_OK {
            NSLog("[EverClip] ERROR: Cannot open database at \(path) (code \(rc))")
            sqlite3_close(db)
            db = nil
        }
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA synchronous=NORMAL")
        exec("PRAGMA foreign_keys=ON")
    }

    // MARK: - Execute

    @discardableResult
    func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    // MARK: - Bind helpers

    func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, csqlite_transient())
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    func bindInt(_ stmt: OpaquePointer?, _ index: Int32, _ value: Int) {
        sqlite3_bind_int(stmt, index, Int32(value))
    }

    func bindDouble(_ stmt: OpaquePointer?, _ index: Int32, _ value: Double) {
        sqlite3_bind_double(stmt, index, value)
    }

    func bindBlob(_ stmt: OpaquePointer?, _ index: Int32, _ value: Data?) {
        if let d = value {
            _ = d.withUnsafeBytes { ptr in
                sqlite3_bind_blob(stmt, index, ptr.baseAddress, Int32(d.count), csqlite_transient())
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    // MARK: - Column readers

    func col(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cStr)
    }

    func colInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int {
        Int(sqlite3_column_int(stmt, index))
    }

    func colDouble(_ stmt: OpaquePointer?, _ index: Int32) -> Double {
        sqlite3_column_double(stmt, index)
    }

    func colBlob(_ stmt: OpaquePointer?, _ index: Int32) -> Data? {
        guard let ptr = sqlite3_column_blob(stmt, index) else { return nil }
        let size = Int(sqlite3_column_bytes(stmt, index))
        return Data(bytes: ptr, count: size)
    }

    deinit {
        sqlite3_close(db)
    }
}
