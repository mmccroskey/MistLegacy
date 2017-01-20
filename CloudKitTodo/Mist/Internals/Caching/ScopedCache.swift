//
//  ScopedCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class ScopedCache {
    
    
    // MARK: - Initializers
    
    init(scope:StorageScope) {
        self.scope = scope
    }
    
    
    // MARK: - Public Properties
    
    let scope: StorageScope
    
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
    
    
    // MARK: - Private Functions
    
    internal func modifySubscriptions(_ subscriptionsToAdd:[CKSubscription]?, idsOfSubscriptionsToDelete:[String]?, completion:((Error?) -> Void)) {
        
        let modifySubsOp = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptionsToAdd, subscriptionIDsToDelete: idsOfSubscriptionsToDelete)
        modifySubsOp.modifySubscriptionsCompletionBlock = { (addedSubscriptions, idsOfDeletedSubscriptions, error) in
            
            completion(error)
            
        }
        
        let database = CKContainer.default().database(with: self.scope)
        database.add(modifySubsOp)
        
    }
    
}
