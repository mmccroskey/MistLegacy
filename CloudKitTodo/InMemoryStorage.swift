//
//  InMemoryLocalRecordStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class InMemoryStorage: LocalRecordStorage, LocalMetadataStorage, LocalCachedRecordChangesStorage {
    
    
    // MARK: - Private Properties
    
    private var storedRecords: [StorageScope : [RecordIdentifier : Record]] = [
        .public  : [:],
        .private : [:],
        .shared  : [:]
    ]
    
    private var metadata: [String:Any?] = [:]
    
    
    // MARK: - LocalCachedRecordChangesStorage Protocol Properties
    
    
    var modifiedRecordsAwaitingPushToCloud: Set<Record> = []
    var deletedRecordsAwaitingPushToCloud: Set<Record> = []
    
    
    // MARK: - LocalRecordStorage Protocol Functions
    
    
    
    // MARK: Adding & Modifying Records
    
    func addRecord(_ record:Record, toStorageWith scope:StorageScope) {
        self.storedRecords[scope]![record.identifier] = record
    }
    
    
    
    // MARK: Removing Records
    
    func removeRecord(_ record:Record, fromStorageWith scope:StorageScope) {
        return self.removeRecord(matching: record.identifier, fromStorageWith: scope)
    }
    
    func removeRecord(matching identifier:RecordIdentifier, fromStorageWith scope:StorageScope) {
        self.storedRecords[scope]!.removeValue(forKey: identifier)
    }
    
    
    // MARK: Finding Records
    
    func record(matching identifier:RecordIdentifier, inStorageWith scope:StorageScope) -> Record? {
        return self.storedRecords[scope]![identifier]
    }
    
    func records(matching filter:((Record) throws -> Bool), inStorageWith scope:StorageScope) rethrows -> [Record] {
        return try self.storedRecords[scope]!.values.filter(filter)
    }
    
    func records(matching predicate:NSPredicate, inStorageWith scope:StorageScope) -> [Record] {
        return self.records(matching: { predicate.evaluate(with: $0) }, inStorageWith: scope)
    }
    
    
    // MARK: - LocalMetadataStorage Protocol Functions
    
    
    // MARK: - Getting Values
    
    func value(forKey key:String) -> Any? {
        return self.metadata[key]
    }
    
    
    // MARK: - Setting Values
    
    func setValue(_ value:Any?, forKey key:String) {
        self.metadata[key] = value
    }
    
}
