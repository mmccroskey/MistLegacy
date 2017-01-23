//
//  RecordZone.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 1/10/17.
//  Copyright © 2017 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class RecordZone : Hashable {
    
    
    // MARK: - Initializers
    
    init() {
        
        let recordZoneId = CKRecordZoneID(zoneName: UUID().uuidString, ownerName: CKCurrentUserDefaultName)
        self.backingRecordZone = CKRecordZone(zoneID: recordZoneId)
        
    }
    
    init(identifier: RecordZoneIdentifier) {
        
        let recordZoneId = CKRecordZoneID(zoneName: identifier, ownerName: CKCurrentUserDefaultName)
        self.backingRecordZone = CKRecordZone(zoneID: recordZoneId)
        
    }
    
    
    // MARK: - Public Properties
    
    var identifier: RecordZoneIdentifier {
        return self.backingRecordZone.zoneID.zoneName
    }
    
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
        
        self.cachedRecords[record.identifier] = record
        self.recordsWithUnpushedChanges[record.identifier] = record
        
    }
    
    func addCachedRecords(_ records:Set<Record>) {
        
        for record in records {
            self.addCachedRecord(record)
        }
        
    }
    
    func removeCachedRecordWithIdentifier(_ identifier:RecordIdentifier) {
        
        if let record = self.cachedRecords[identifier] {
            
            self.recordsWithUnpushedChanges.removeValue(forKey: record.identifier)
            self.recordsWithUnpushedDeletions[record.identifier] = record
            self.cachedRecords.removeValue(forKey: record.identifier)
            
        }
        
    }
    
    func removeCachedRecordsWithIdentifiers(_ identifiers:Set<RecordIdentifier>) {
        
        for identifier in identifiers {
            self.removeCachedRecordWithIdentifier(identifier)
        }
        
    }
    
    
    // MARK: - Internal Properties
    
    internal let backingRecordZone: CKRecordZone
    
    
    // MARK: - Private Properties
    
    private var cachedRecords: [RecordIdentifier : Record] = [:]
    
    
    // MARK: - Protocol Conformance
    
    var hashValue: Int {
        return self.backingRecordZone.hashValue
    }
    
    static func ==(left:RecordZone, right:RecordZone) -> Bool {
        return left.backingRecordZone == right.backingRecordZone
    }
    
}
