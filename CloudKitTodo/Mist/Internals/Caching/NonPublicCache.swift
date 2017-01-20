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
        
        func fetchDatabaseChangesOperation() {
            
            let dbChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
            dbChangesOperation.fetchAllChanges = true
            dbChangesOperation.changeTokenUpdatedBlock = { self.databaseChangeToken = $0 }
            dbChangesOperation.recordZoneWithIDWasDeletedBlock = { idsOfDeletedRecordZones.append($0) }
            dbChangesOperation.recordZoneWithIDChangedBlock = { idsOfUpdatedRecordZones.append($0) }
            dbChangesOperation.fetchDatabaseChangesCompletionBlock = { (serverChangeToken, moreComing, error) in
                
                guard moreComing == false else {
                    fatalError("We specified that we wanted to fetch all changes, so moreComing should always be false.")
                }
                
                self.databaseChangeToken = serverChangeToken
                
                if moreComing {
                    
                    fetchDatabaseChangesOperation()
                    
                } else {
                    
                    for idOfDeletedRecordZone in idsOfDeletedRecordZones {
                        
                        // Find all local Records in this Record Zone and delete them, 
                        // ensuring that related records are also deleted
                        
                    }
                    
                    var idsOfDeletedRecords: [CKRecordID] = []
                    
                    // TODO: Cache and pass per-record-zone change tokens here
                    let recordZoneChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: idsOfUpdatedRecordZones, optionsByRecordZoneID: nil)
                    recordZoneChangesOperation.fetchAllChanges = true
                    recordZoneChangesOperation.recordWithIDWasDeletedBlock = { (recordId, string) in idsOfDeletedRecords.append(recordId) }
                    
                    
                }
                
            }
            
        }
        
        
    }
    
    
    // MARK: - Private Properties
    
    private var databaseSubscriptionId: String? = nil
    
    
}
