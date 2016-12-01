//
//  InMemoryLocalRecordStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class InMemoryLocalRecordStorage: LocalRecordStorage {
    
    
    // MARK: - Adding & Modifying Records
    
    func addRecord(_ record:Record) {
        self.allRecords[record.identifier] = record
    }
    
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:Record) -> Bool {
        return self.removeRecord(matching: record.identifier)
    }
    
    func removeRecord(matching identifier:RecordIdentifier) -> Bool {
        
        let value = self.allRecords.removeValue(forKey: identifier)
        return (value != nil)
        
    }
    
    
    // MARK: - Finding Records
    
    func record(matching identifier:RecordIdentifier) -> Record? {
        return self.allRecords[identifier]
    }
    
    func records(matching filter:((Record) throws -> Bool)) rethrows -> [Record] {
        return try self.allRecords.values.filter(filter)
    }
    
    func records(matching predicate:NSPredicate) -> [Record] {
        return self.records(matching: {  predicate.evaluate(with: $0) })
    }
    

    // MARK: - Private Properties
    
    private var allRecords: [RecordIdentifier : Record] = [:]
    
}
