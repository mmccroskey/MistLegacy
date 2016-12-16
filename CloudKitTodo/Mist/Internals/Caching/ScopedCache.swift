//
//  ScopedCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class ScopedCache {
    
    
    // MARK: - Public Properties
    
    var recordsWithUnpushedChanges: [RecordIdentifier : Record] = [:]
    var recordsWithUnpushedDeletions: [RecordIdentifier : Record] = [:]
    
    
    // MARK: - Public Functions
    
    func cachedRecordWithIdentifier(_ identifier:RecordIdentifier) -> Record? {
        return self.cachedRecords[identifier]
    }
    
    func cachedRecords(matching filter:FilterClosure) throws -> [Record] {
        return try self.cachedRecords.values.filter(filter)
    }
    
    func addCachedRecord(_ record:Record) {
        self.addCachedRecords([record])
    }
    
    func addCachedRecords(_ records:Set<Record>) {
        
        for record in records {
            self.cachedRecords[record.identifier] = record
        }
        
    }
    
    func removeCachedRecordWithIdentifier(_ identifier:RecordIdentifier) {
        self.removeCachedRecordsWithIdentifiers([identifier])
    }
    
    func removeCachedRecordsWithIdentifiers(_ identifiers:Set<RecordIdentifier>) {
        
        for identifier in identifiers {
            self.cachedRecords.removeValue(forKey: identifier)
        }
        
    }
    
    
    // MARK: - Private Properties
    
    private var cachedRecords: [RecordIdentifier : Record] = [:]
    
}
