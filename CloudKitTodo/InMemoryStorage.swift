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
    
    private var records: [RecordIdentifier : Record] = [:]
    private var metadata: [String:Any?] = [:]
    
    
    // MARK: - LocalCachedRecordChangesStorage Protocol Properties
    
    
    var modifiedRecordsAwaitingPushToCloud: Set<Record> = []
    var deletedRecordsAwaitingPushToCloud: Set<Record> = []
    
    
    // MARK: - LocalRecordStorage Protocol Functions
    
    
    
    // MARK: Adding & Modifying Records
    
    func addRecord(_ record:Record) {
        self.records[record.identifier] = record
    }
    
    
    
    // MARK: Removing Records
    
    func removeRecord(_ record:Record) {
        return self.removeRecord(matching: record.identifier)
    }
    
    func removeRecord(matching identifier:RecordIdentifier) {
        self.records.removeValue(forKey: identifier)
    }
    
    
    // MARK: Finding Records
    
    func record(matching identifier:RecordIdentifier) -> Record? {
        return self.records[identifier]
    }
    
    func records(matching filter:((Record) throws -> Bool)) rethrows -> [Record] {
        return try self.records.values.filter(filter)
    }
    
    func records(matching predicate:NSPredicate) -> [Record] {
        return self.records(matching: {  predicate.evaluate(with: $0) })
    }
    
    
    // MARK: - LocalMetadataStorage Protocol Functions
    
    
    // MARK: - Getting Values
    
    func value(for key:String) -> Any? {
        return self.metadata[key]
    }
    
    
    // MARK: - Setting Values
    
    func setValue(_ value:Any?, for key:String) -> Bool {
        
        self.metadata[key] = value
        return true
        
    }
    
}
