//
//  PublicCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class PublicCache: ScopedCache {
    
    
    // MARK: - Public Functions
    
    override func addCachedRecord(_ record:Record) {
        self.addCachedRecords([record])
    }
    
    override func addCachedRecords(_ records:Set<Record>) {
    
        self.addRecordsToLocallyCreatedRecords(records)
        super.addCachedRecords(records)
    
    }
    
    override func removeCachedRecordWithIdentifier(_ identifier:RecordIdentifier) {
        self.removeCachedRecordsWithIdentifiers([identifier])
    }
    
    override func removeCachedRecordsWithIdentifiers(_ identifiers: Set<RecordIdentifier>) {
        
        var recordsToDelete: Set<Record> = []
        
        for identifier in identifiers {
            
            if let extantRecord = self.cachedRecordWithIdentifier(identifier) {
                recordsToDelete.insert(extantRecord)
            }
            
        }
        
        self.removeRecordsFromLocallyCreatedRecords(recordsToDelete)
        super.removeCachedRecordsWithIdentifiers(identifiers)
        
    }
    
    
    // MARK: - Private Properties
    
    private var idsOflocallyCreatedRecordsByRecordType: [String : Set<RecordIdentifier>] = [:]
    private var querySubscriptionsForLocallyCreatedRecordsByRecordType: [String : CKQuerySubscription] = [:]
    
    
    // MARK: - Private Functions
    
    private func addRecordsToLocallyCreatedRecords(_ records:Set<Record>) {
        
        for record in records {
            
            let typeString = record.typeString
            
            var recordIdsForRecordType: Set<RecordIdentifier>
            if let extantRecordIdsForRecordType = self.idsOflocallyCreatedRecordsByRecordType[typeString] {
                recordIdsForRecordType = extantRecordIdsForRecordType
            } else {
                recordIdsForRecordType = []
            }
            
            recordIdsForRecordType.insert(record.identifier)
            
            self.idsOflocallyCreatedRecordsByRecordType[typeString] = recordIdsForRecordType
            
        }
        
        self.updateQuerySubscriptions()
        
    }
    
    private func removeRecordsFromLocallyCreatedRecords(_ records:Set<Record>) {
        
        for record in records {
            
            if var recordIdsForRecordType = self.idsOflocallyCreatedRecordsByRecordType[record.typeString] {
                
                recordIdsForRecordType.remove(record.identifier)
                self.idsOflocallyCreatedRecordsByRecordType[record.typeString] = recordIdsForRecordType
                
            }
            
        }
        
        self.updateQuerySubscriptions()
        
    }
    
    private func updateQuerySubscriptions() {
        
        let recordIdsRecordTypes: [String] = self.idsOflocallyCreatedRecordsByRecordType.keys.map { (key) -> String in return key }
        let recordIdsRecordTypesSet: Set<String> = Set(recordIdsRecordTypes)
        
        let querySubscriptionsRecordTypes: [String] = self.querySubscriptionsForLocallyCreatedRecordsByRecordType.keys.map { (key) -> String in return key }
        let querySubscriptionsRecordTypesSet: Set<String> = Set(querySubscriptionsRecordTypes)
        
        let unionedRecordTypesSet = recordIdsRecordTypesSet.union(querySubscriptionsRecordTypesSet)
        
        var querySubscriptionsToAdd: [CKQuerySubscription] = []
        var idsOfQuerySubscriptionsToDelete: [String] = []
        
        for recordTypeString in unionedRecordTypesSet {
            
            let recordIdsForRecordType = self.idsOflocallyCreatedRecordsByRecordType[recordTypeString]
            let querySubscriptionForRecordType = self.querySubscriptionsForLocallyCreatedRecordsByRecordType[recordTypeString]
            
            if let querySubscriptionForRecordType = querySubscriptionForRecordType, recordIdsForRecordType == nil {
                
                // If we have a query subscription for the recordTypeString but no RecordIdentifiers, then this query subscription is out of date and should be deleted
                
                idsOfQuerySubscriptionsToDelete.append(querySubscriptionForRecordType.subscriptionID)
                self.querySubscriptionsForLocallyCreatedRecordsByRecordType.removeValue(forKey: recordTypeString)
                
                
            } else if let recordIdsForRecordType = recordIdsForRecordType {
                
                // If we have RecordIdentifiers for the recordTypeString, then set up a fresh Query that describes them
                
                let recordIdsForRecordTypeStringArray: [String] = recordIdsForRecordType.map({ (recordId) -> String in return recordId as String })
                
                let predicate = NSPredicate(format: "recordID.recordName IN %@", recordIdsForRecordTypeStringArray)
                let subscriptionId = UUID().uuidString
                let subscriptionOptions: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
                let querySubscription = CKQuerySubscription(recordType: recordTypeString, predicate: predicate, subscriptionID: subscriptionId, options: subscriptionOptions)
                
                querySubscriptionsToAdd.append(querySubscription)
                self.querySubscriptionsForLocallyCreatedRecordsByRecordType[recordTypeString] = querySubscription
                
            } else {
                
                // Given the way we construct the unionedRecordTypesSet, we should never hit this else
                fatalError("This else block should never fire -- check the construction of the recordIdsForRecordType set.")
                
            }
            
        }
        
        let modifySubsOp = CKModifySubscriptionsOperation(subscriptionsToSave: querySubscriptionsToAdd, subscriptionIDsToDelete: idsOfQuerySubscriptionsToDelete)
        modifySubsOp.modifySubscriptionsCompletionBlock = { (addedSubscriptions, idsOfDeletedSubscriptions, error) in
            
            guard error == nil else {
                
                // TODO: Handle this error better
                fatalError("Failed to modify subscriptions due to error: \(error!)")
                
            }
            
        }
        
    }
    
}
