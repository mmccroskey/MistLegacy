//
//  NonPublicCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/10/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class NonPublicCache: ScopedCache {
    
    
    // MARK: - Internal Properties
    
    var databaseChangeToken: CKServerChangeToken? = nil
    var recordZoneChangeTokens: [RecordZoneIdentifier : CKServerChangeToken?] = [:]
    
    
    // MARK: - Internal Functions
    
    internal func adjustDatabaseSubscription(_ automaticSyncEnabled:Bool, completion:((Error?) -> Void)) {
        
        if automaticSyncEnabled == true {
            
            let subscriptionId: String
            if let extantSubscriptionId = self.databaseSubscriptionId {
                subscriptionId = extantSubscriptionId
            } else {
                
                switch self.scope {
                    
                case .private:
                    subscriptionId = "private"
                    
                case .shared:
                    subscriptionId = "shared"
                    
                default:
                    fatalError("The scope specified for a NonPublicCache should only ever be `private` or `shared`.")
                    
                }
                
                self.databaseSubscriptionId = subscriptionId
                
            }
            
            let subscription = CKDatabaseSubscription(subscriptionID: subscriptionId)
            
            let notificationInfo = CKNotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            self.modifySubscriptions([subscription], idsOfSubscriptionsToDelete: nil, completion: completion)
            
        } else {
            
            if let extantSubscriptionId = self.databaseSubscriptionId {
                self.modifySubscriptions(nil, idsOfSubscriptionsToDelete: [extantSubscriptionId], completion: completion)
            }
            
        }
        
    }
    
    internal func handleNotification() {
        
        var idsOfDeletedRecordZones: [CKRecordZoneID] = []
        var idsOfUpdatedRecordZones: [CKRecordZoneID] = []
        
        let dbChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        dbChangesOperation.fetchAllChanges = true
        dbChangesOperation.changeTokenUpdatedBlock = { self.databaseChangeToken = $0 }
        dbChangesOperation.recordZoneWithIDWasDeletedBlock = { idsOfDeletedRecordZones.append($0) }
        dbChangesOperation.recordZoneWithIDChangedBlock = { idsOfUpdatedRecordZones.append($0) }
        dbChangesOperation.fetchDatabaseChangesCompletionBlock = { (serverChangeToken, moreComing, error) in
            
            guard error == nil else {
                // TODO: Better error handling
                fatalError("An error occurred while fetching database changes: \(error)")
            }
            
            guard moreComing == false else {
                fatalError("We specified that we wanted to fetch all changes, so moreComing should always be false.")
            }
            
            self.databaseChangeToken = serverChangeToken
            
            for idOfDeletedRecordZone in idsOfDeletedRecordZones {
                
                // TODO: Find all local Records in this Record Zone and delete them,
                // ensuring that related records are also deleted
                
            }
            
            var recordIdentifiersOfDeletedRecords: Set<RecordIdentifier> = []
            var modifiedRecords: [CKRecord] = []
            
            // TODO: Cache and pass per-record-zone change tokens here
            let recordZoneChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: idsOfUpdatedRecordZones, optionsByRecordZoneID: nil)
            recordZoneChangesOperation.fetchAllChanges = true
            recordZoneChangesOperation.recordWithIDWasDeletedBlock = { (recordId, string) in recordIdentifiersOfDeletedRecords.insert(recordId.recordName) }
            recordZoneChangesOperation.recordChangedBlock = { modifiedRecords.append($0) }
            recordZoneChangesOperation.fetchRecordZoneChangesCompletionBlock = { error in
                
                guard error == nil else {
                    // TODO: Better error handling
                    fatalError("An error occurred while fetching record zone changes: \(error)")
                }
                
                Mist.fetch(recordIdentifiersOfDeletedRecords, from: self.scope, finished: { (recordOperationResult, records) in
                    
                    guard recordOperationResult.succeeded == true else {
                        fatalError("Could not fetch records due to record operation error: \(recordOperationResult.error!)")
                    }
                    
                    if let records = records {
                        
                        Mist.internalRemove(Set(records), from: self.scope, finished: { (removeOperationResult) in
                            
                            guard removeOperationResult.succeeded == true else {
                                fatalError("Could not remove records due to record operation error: \(removeOperationResult.error!)")
                            }
                            
                        })
                        
                    }
                    
                })
                
                let recordsToAdd = modifiedRecords.map({ Record(backingRemoteRecord:$0) })
                Mist.internalAdd(Set(recordsToAdd), to: self.scope, finished: { (addOperationResult) in
                    
                    guard addOperationResult.succeeded == true else {
                        fatalError("Could not add records due to record operation error: \(addOperationResult.error!)")
                    }
                    
                })
                
            }
            
        }
        
        
    }
    
    
    // MARK: - Private Properties
    
    private var databaseSubscriptionId: String? = nil
    
    
}
