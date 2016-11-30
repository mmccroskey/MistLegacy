//
//  InMemoryLocalStorageInterface.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class InMemoryLocalStorageInterface: LocalStorageInterface {
    
    
    // MARK: - Retrieving Records
    
    func allRecords() -> Set<LocalRecord> {
        return Set(self.records.values)
    }
    
    func record(matching recordIdentifier:RecordIdentifier) -> LocalRecord? {
        return self.records[recordIdentifier]
    }
    
    
    // MARK: - Adding Records
    
    func addRecord(_ record:LocalRecord) {
        self.records[record.identifier] = record
    }
    
    func addRecords(_ records:Set<LocalRecord>) {
        
        for record in records {
            self.records[record.identifier] = record
        }
        
    }
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:LocalRecord) {
        self.removeRecord(matching: record.identifier)
    }
    
    func removeRecord(matching recordIdentifier:RecordIdentifier) {
        self.records.removeValue(forKey: recordIdentifier)
    }
    
    func removeAllRecords() {
        self.records.removeAll()
    }
    
    
    // MARK: - Private Properties
    
    private var records: [RecordIdentifier : LocalRecord] = [:]
    
    
    
}
