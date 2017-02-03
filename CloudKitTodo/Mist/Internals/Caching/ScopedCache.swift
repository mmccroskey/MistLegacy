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
        
        let defaultRecordZone = RecordZone(identifier: "default")
        self.addCachedRecordZone(defaultRecordZone)
        
    }
    
    
    // MARK: - Public Properties
    
    let scope: StorageScope
    
    var defaultRecordZone: RecordZone {
        
        guard let recordZone = self.cachedRecordZoneWithIdentifier("default") else {
            fatalError("Every Database should have a default Record Zone")
        }
        
        return recordZone
        
    }
    
    private(set) var cachedRecordZones: [RecordZoneIdentifier : RecordZone] = [:]
    private(set) var recordZonesWithUnpushedChanges: [RecordZoneIdentifier : RecordZone] = [:]
    private(set) var recordZonesWithUnpushedDeletions: [RecordZoneIdentifier : RecordZone] = [:]
    
    
    // MARK: - Public Functions
    
    func cachedRecordZoneWithIdentifier(_ identifier:RecordZoneIdentifier) -> RecordZone? {
        return self.cachedRecordZones[identifier]
    }
    
    func addCachedRecordZone(_ recordZone:RecordZone) {
        
        self.cachedRecordZones[recordZone.identifier] = recordZone
        self.recordZonesWithUnpushedChanges[recordZone.identifier] = recordZone
        
    }
    
    func addCachedRecordZones(_ recordZones:Set<RecordZone>) {
        
        for recordZone in recordZones {
            self.addCachedRecordZone(recordZone)
        }
        
    }
    
    func removeCachedRecordZoneWithIdentifier(_ identifier:RecordZoneIdentifier) {
        
        if let recordZone = self.cachedRecordZones[identifier] {
            
            self.recordZonesWithUnpushedChanges.removeValue(forKey: recordZone.identifier)
            self.recordZonesWithUnpushedDeletions[recordZone.identifier] = recordZone
            self.cachedRecordZones.removeValue(forKey: identifier)
            
        }
        
    }
    
    func removeCachedRecordZonesWithIdentifiers(_ identifiers:Set<RecordZoneIdentifier>) {
        
        for identifier in identifiers {
            self.removeCachedRecordZoneWithIdentifier(identifier)
        }
        
    }
    
    
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
