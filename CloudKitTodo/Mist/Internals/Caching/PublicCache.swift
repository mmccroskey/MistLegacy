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
    
    
    // MARK: - Initializers
    
    init() {
        super.init(scope: .public)
    }
    
    
    // MARK: - Internal Functions
    
    override func cachedRecordZoneWithIdentifier(_ identifier:RecordZoneIdentifier) -> RecordZone? {
        self.handleCallsToUnsupportedFunctions()
    }
    
    override func addCachedRecordZone(_ recordZone:RecordZone) {
        self.handleCallsToUnsupportedFunctions()
    }
    
    override func addCachedRecordZones(_ recordZones:Set<RecordZone>) {
        self.handleCallsToUnsupportedFunctions()
    }
    
    override func removeCachedRecordZoneWithIdentifier(_ identifier:RecordZoneIdentifier) {
        self.handleCallsToUnsupportedFunctions()
    }
    
    override func removeCachedRecordZonesWithIdentifiers(_ identifiers:Set<RecordZoneIdentifier>) {
        self.handleCallsToUnsupportedFunctions()
    }
    
    func handleNotification() {
        
        var modifiedNotifications: [CKNotification] = []
        
        func executeNotificationChangesOperation(withChangeToken previousServerChangeToken: CKServerChangeToken?=nil) {
            
            let changesOperation = CKFetchNotificationChangesOperation(previousServerChangeToken: previousServerChangeToken)
            changesOperation.notificationChangedBlock = { modifiedNotifications.append($0) }
            changesOperation.fetchNotificationChangesCompletionBlock = { (serverChangeToken, error) in
                
                guard error == nil else {
                    fatalError("An error occurred while fetching notification changes: \(error)")
                }
                
                if let serverChangeToken = serverChangeToken {
                    
                    executeNotificationChangesOperation(withChangeToken: serverChangeToken)
                    
                } else {
                    
                    var idsOfModifiedRecords: [CKRecordID] = []
                    
                    for modifiedNotification in modifiedNotifications {
                        
                        guard let queryNotification = modifiedNotification as? CKQueryNotification else {
                            fatalError("All notification objects associated with the public database should be query notifications.")
                        }
                        
                        guard let recordId = queryNotification.recordID else {
                            fatalError("A non-pruned query notification should always have a recordID.")
                        }
                        
                        switch queryNotification.queryNotificationReason {
                            
                        case .recordCreated, .recordUpdated:
                            idsOfModifiedRecords.append(recordId)
                            
                        case .recordDeleted:
                            self.removeCachedRecordWithIdentifier(recordId.recordName)
                            
                        }
                        
                    }
                    
                    let fetchOperation = CKFetchRecordsOperation(recordIDs: idsOfModifiedRecords)
                    fetchOperation.fetchRecordsCompletionBlock = { (recordIdRecordPairs, error) in
                        
                        guard let recordIdRecordPairs = recordIdRecordPairs, error == nil else {
                            fatalError("Fetching of updated records failed due to error: \(error)")
                        }
                        
                        for recordIdRecordPair in recordIdRecordPairs {
                            
                            let ckRecord = recordIdRecordPair.value
                            let recordType = ckRecord.recordType
                            
                            let mistRecord = Record(className: recordType, backingRemoteRecord: ckRecord)
                            super.addCachedRecord(mistRecord)
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        executeNotificationChangesOperation()
        
    }
    
    internal func adjustQuerySubscriptions(_ automaticSyncEnabled:Bool, completion:((Error?) -> Void)) {
        
        if automaticSyncEnabled == true {
            
            let existingQuerySubscriptions = self.querySubscriptionsForLocallyCreatedRecordsByRecordType.values.map({ $0 }) as [CKQuerySubscription]
            self.modifySubscriptions(existingQuerySubscriptions, idsOfSubscriptionsToDelete: nil, completion: completion)
            
        } else {
            
            let idsOfExistingSubscriptions = self.querySubscriptionsForLocallyCreatedRecordsByRecordType.values.map({ $0.subscriptionID }) as [String]
            self.modifySubscriptions(nil, idsOfSubscriptionsToDelete: idsOfExistingSubscriptions, completion: completion)
            
        }
        
    }
    
    
    // MARK: - Private Properties
    
    private var idsOflocallyCreatedRecordsByRecordType: [String : Set<RecordIdentifier>] = [:]
    private var querySubscriptionsForLocallyCreatedRecordsByRecordType: [String : CKQuerySubscription] = [:]
    
    
    // MARK: - Private Functions
    
    private func handleCallsToUnsupportedFunctions() -> Never {
        fatalError("The Public Database only has one Record Zone: the default Record Zone.")
    }
    
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
                let subscriptionOptions: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
                let querySubscription = CKQuerySubscription(recordType: recordTypeString, predicate: predicate, subscriptionID: recordTypeString, options: subscriptionOptions)
                
                let notificationInfo = CKNotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                querySubscription.notificationInfo = notificationInfo
                
                querySubscriptionsToAdd.append(querySubscription)
                self.querySubscriptionsForLocallyCreatedRecordsByRecordType[recordTypeString] = querySubscription
                
            } else {
                
                // Given the way we construct the unionedRecordTypesSet, we should never hit this else
                fatalError("This else block should never fire -- check the construction of the recordIdsForRecordType set.")
                
            }
            
        }
        
        self.modifySubscriptions(querySubscriptionsToAdd, idsOfSubscriptionsToDelete: idsOfQuerySubscriptionsToDelete, completion: { (error) in
            
            // TODO: Handle this better
            guard error == nil else {
                fatalError("Subscriptions were not modified due to error \(error)")
            }
            
        })
        
    }
    
}
