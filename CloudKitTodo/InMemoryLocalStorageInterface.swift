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
    
    func allRecords() -> Set<Record> {
        return Set(self.records.values)
    }
    
    func record(matching recordIdentifier:RecordIdentifier) -> Record? {
        return self.records[recordIdentifier]
    }
    
    
    // MARK: - Adding Records
    
    func addRecord(_ record:Record) {
        self.records[record.identifier] = record
        self.changedRecordsAwaitingPushToCloud.insert(record)
    }
    
    func addRecords(_ records:Set<Record>) {
        
        for record in records {
            self.addRecord(record)
        }
        
    }
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:Record) {
        self.removeRecord(matching: record.identifier)
        self.deletedRecordsAwaitingPushToCloud.insert(record)
        self.changedRecordsAwaitingPushToCloud.remove(record)
    }
    
    func removeRecord(matching recordIdentifier:RecordIdentifier) {
        
        if let record = self.records[recordIdentifier] {
            self.removeRecord(record)
        }
        
    }
    
    func removeAllRecords() {
        
        let allRecordsSet = Set(self.records.values)
        self.deletedRecordsAwaitingPushToCloud = self.deletedRecordsAwaitingPushToCloud.union(allRecordsSet)
        
        self.records.removeAll()
        
    }
    
    
    // MARK: - Storage for Changes Awaiting Push To Cloud
    
    var changedRecordsAwaitingPushToCloud: Set<Record> = []
    var deletedRecordsAwaitingPushToCloud: Set<Record> = []
    
    
    // MARK: - Private Properties
    
    private var records: [RecordIdentifier : Record] = [:]
    
    
    
}
