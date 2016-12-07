//
//  RemoteDataCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/5/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class RemoteDataCoordinator : DataCoordinator {
    
    private class CKRecordSet {
        
        convenience init(records: [CKRecord]) {
            self.init()
            self.records = records
        }
        
        private(set) var records: [CKRecord] = []
        
        func insert(_ record:CKRecord) {
            
            // Remove the record from the array if it's already in there
            remove(record)
            
            records.append(record)
            
        }
        
        func remove(_ record:CKRecord) {
            
            records = records.filter({ (recordInArray) -> Bool in
                return recordInArray.recordID.recordName != record.recordID.recordName
            })
            
        }
        
        func union(_ otherRecordSet:CKRecordSet) -> CKRecordSet {
            
            let selfCopy = CKRecordSet(records: records)
            
            let recordsFromOtherSet = otherRecordSet.records
            for recordFromOtherSet in recordsFromOtherSet {
                
                selfCopy.insert(recordFromOtherSet)
                
            }
            
            return selfCopy
            
        }
        
        func recordIDs() -> [CKRecordID] {
            
            let recordIds = records.map { (record) -> CKRecordID in
                return record.recordID
            }
            
            return recordIds
            
        }
        
    }
    
    
    // MARK: - Private Variables and Metadata Accessors
    
    
    // MARK: Container
    
    private let container = CKContainer.default()
    
    
    // MARK: Databases
    
    private func database(forScope scope:CKDatabaseScope) -> CKDatabase {
        
        switch scope {
            
        case .public:
            return self.container.publicCloudDatabase
            
        case .private:
            return self.container.privateCloudDatabase
            
        case .shared:
            return self.container.sharedCloudDatabase
            
        }
        
    }
    
    
    // MARK: Database Server Change Tokens
    
    private func databaseServerChangeToken(forScope scope:CKDatabaseScope, retrievalCompleted:((CKServerChangeToken?) -> Void)) {
        
        if let key = self.databaseServerChangeTokenKey(forScope: scope) {
            
            self.metadata(forKey: key, retrievalCompleted: { (value) in
                
                if let existingChangeToken = value as? CKServerChangeToken {
                    retrievalCompleted(existingChangeToken)
                } else {
                    retrievalCompleted(nil)
                }
                
            })
            
        }
        
    }
    
    private func setDatabaseServerChangeToken(_ changeToken:CKServerChangeToken?, forScope scope:CKDatabaseScope) {
        
        if let key = self.databaseServerChangeTokenKey(forScope: scope) {
            self.setMetadata(changeToken, forKey: key)
        }
        
    }
    
    private func databaseServerChangeTokenKey(forScope scope:CKDatabaseScope) -> String? {
        
        let key: String?
        
        switch scope {
            
        case .private:
            key = "privateDatabaseServerChangeToken"
            
        case .shared:
            key = "sharedDatabaseServerChangeToken"
            
        default:
            key = nil
            
        }
        
        return key
        
    }
    
    
    // MARK: Record Zone Server Change Tokens
    
    private typealias RecordZoneIdentifier = String
    
    private func recordZonesServerChangeTokens(forScope scope:CKDatabaseScope, retrievalCompleted:(([RecordZoneIdentifier : CKServerChangeToken?]) -> Void)) {
        
        if let key = self.recordZonesServerChangeTokensKey(forScope: scope) {
            
            self.metadata(forKey: key, retrievalCompleted: { (value) in
                
                if let existingChangeTokens = value as? [RecordZoneIdentifier : CKServerChangeToken?] {
                    retrievalCompleted(existingChangeTokens)
                } else {
                    retrievalCompleted([:])
                }
                
            })
            
        }
        
    }
    
    private func setRecordZonesServerChangeTokens(_ changeTokens:[RecordZoneIdentifier : CKServerChangeToken?], forScope scope:CKDatabaseScope) {
        
        if let key = self.recordZonesServerChangeTokensKey(forScope: scope) {
            self.setMetadata(changeTokens, forKey: key)
        }
        
    }
    
    private func recordZonesServerChangeTokensKey(forScope scope:CKDatabaseScope) -> String? {
        
        let key: String?
        
        switch scope {
            
        case .private:
            key = "privateRecordZonesServerChangeToken"
            
        case .shared:
            key = "sharedRecordZonesServerChangeToken"
            
        default:
            key = nil
            
        }
        
        return key
        
    }
    
    
    // MARK: - Preflighting
    
    func confirmICloudAvailable(_ completion:SyncStepCompletion) {
        
        self.container.accountStatus { (status, error) in
            
            guard error == nil else {
                
                completion(SyncStepResult(success: false, error: error!))
                return
                
            }
            
            switch status {
                
            case .available:
                completion(SyncStepResult(success: true))
                
            case .noAccount:
                
                let noAccountError = ErrorStruct(
                    code: 404, title: "No Account",
                    failureReason: "The User is not logged in to iCloud.",
                    description: "Ask the User to log in to iCloud."
                )
                
                completion(SyncStepResult(success: false, error: noAccountError.errorObject()))
                
            case .restricted:
                
                let accountAccessRestrictedError = ErrorStruct(
                    code: 403, title: "iCloud Account Restricted",
                    failureReason: "The User's iCloud account is not authorized for use with CloudKit due to parental control or enterprise (MDM) device restrictions.",
                    description: "Ask the User to adjust their parental controls or enterprise device (MDM) settings."
                )
                
                completion(SyncStepResult(success: false, error: accountAccessRestrictedError.errorObject()))
                
            case .couldNotDetermine:
                
                let indeterminateError = ErrorStruct(
                    code: 500, title: "Unexpected Error",
                    failureReason: "The User's iCloud account status is unknown, but CloudKit has failed to provide an error describing why.",
                    description: "Please try this request again later."
                )
                
                completion(SyncStepResult(success: false, error: indeterminateError.errorObject()))
                
            }
            
        }
        
    }
    
    func confirmUserAuthenticated(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        guard previousResult.success == true else {
            completion(previousResult)
            return
        }
        
        CKContainer.default().fetchUserRecordID { (recordId, error) in
            
            guard error == nil else {
                completion(SyncStepResult(success: false, error: error!))
                return
            }
            
            guard let recordId = recordId else {
                
                let indeterminateError = ErrorStruct(
                    code: 404, title: "User Record Not Found on Server",
                    failureReason: "CloudKit failed to return a User record with the ID that CloudKit itself provided. This shouldn't happen.",
                    description: "Please try this request again later."
                )
                
                completion(SyncStepResult(success: false, error: indeterminateError.errorObject()))
                
                return
                
            }
            
            completion(SyncStepResult(success: true, value: recordId))
            
        }
        
    }
    
    func confirmUserRecordExists(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        guard previousResult.success == true else {
            completion(previousResult)
            return
        }
        
        guard let recordId = previousResult.value as? CKRecordID else {
            fatalError("Formatting of content from confirmUserAuthenticated doesn't match expectations.")
        }
        
        let publicDatabase = self.container.publicCloudDatabase
        publicDatabase.fetch(withRecordID: recordId, completionHandler: { (record, error) in
            
            guard error == nil, let record = record else {
                completion(SyncStepResult(success: false, error: error!))
                return
            }
            
            // TODO: Handle case where User has changed
            let user = Record(backingRemoteRecord: record)
            Mist.add(user, to: .public)
            
            completion(SyncStepResult(success: true))
            
        })
        
    }
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performPublicDatabasePull(_ completed:((DirectionalSyncSummary) -> Void)) {
        
        guard let descriptors = Mist.config.public.pullRecordsMatchingDescriptors else {
            completed(DirectionalSyncSummary(result: .success))
            return
        }
        
        for descriptor in descriptors {
            
            let recordTypeString = String(describing: descriptor.type)
            let query = CKQuery(recordType: recordTypeString, predicate: descriptor.descriptor)
            
            var queryCursor: CKQueryCursor? = nil
            var fetchedRecords: Set<CKRecord> = []
            
            func performQuery() {
                
                let queryOperation = CKQueryOperation(query: query)
                queryOperation.cursor = queryCursor
                queryOperation.recordFetchedBlock = { fetchedRecords.insert($0) }
                queryOperation.queryCompletionBlock = { (cursor, error) in
                    
                    guard error == nil else {
                        
                        let result: SyncResult = (queryCursor == nil) ? .totalFailure : .partialFailure
                        completed(DirectionalSyncSummary(result: result, error: error!))
                        return
                        
                    }
                    
                    if let cursor = cursor {
                        
                        queryCursor = cursor
                        performQuery()
                        
                    } else {
                        
                        
                        var mistRecords: Set<Record> = []
                        for fetchedRecord in fetchedRecords {
                            
                            let mistRecord = Record(backingRemoteRecord: fetchedRecord)
                            mistRecords.insert(mistRecord)
                            
                        }
                        
                        Mist.localDataCoordinator.addRecords(mistRecords, toStorageWith: .public, finished: { (storageOperationResult) in
                            
                            guard storageOperationResult.succeeded == true else {
                                
                                if let error = storageOperationResult.error {
                                    completed(DirectionalSyncSummary(result: .partialFailure, error: error))
                                } else {
                                    completed(DirectionalSyncSummary(result: .partialFailure))
                                }
                                
                                return
                                
                            }
                            
                            let recordIdentifiers = fetchedRecords.map({ $0.recordID.recordName })
                            completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: recordIdentifiers, idsOfRecordsDeleted: []))
                            
                        })
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func performDatabasePull(for scope:CKDatabaseScope, completed:((ZoneBasedDirectionalSyncSummary) -> Void)) {
        
        func errorsArray(from optionalError:Error?) -> [Error] {
            
            var errors: [Error] = []
            if let error = optionalError {
                errors.append(error)
            }
            
            return errors
            
        }
        
        func deleteInvalidatedZones(forZonesWithIds idsOfZonesToDelete: Set<CKRecordZoneID>, completed:((ZonedSyncSummary) -> Void)) {
            
            let recordInADeletedZone: ((Record) throws -> Bool) = { (record) in
                
                if let recordZone = record.recordZone {
                    return idsOfZonesToDelete.contains(recordZone.zoneID)
                }
                
                return false
                
            }
            
            Mist.localDataCoordinator.retrieveRecords(matching: recordInADeletedZone, inStorageWithScope: scope, fetchDepth: -1) { (operationResult, records) in
                
                guard operationResult.succeeded == true else {
                    
                    let errors = errorsArray(from: operationResult.error)
                    completed(ZonedSyncSummary(result: .totalFailure, errors: errors, idsOfRelevantRecords: []))
                    
                    return
                    
                }
                
                if let records = records {
                    
                    let recordsSet = Set(records)
                    
                    Mist.localDataCoordinator.removeRecords(recordsSet, fromStorageWith: scope, finished: { (removeOperationResult) in
                        
                        let recordIds = recordsSet.map({ $0.identifier })
                        
                        guard removeOperationResult.succeeded == true else {
                            
                            let errors = errorsArray(from: removeOperationResult.error)
                            completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                            
                            return
                            
                        }
                        
                        completed(ZonedSyncSummary(result: .success, errors:[], idsOfRelevantRecords: recordIds))
                        
                    })
                    
                }
                
            }
            
        }
        
        func fetchZoneChanges(forZonesWithIds idsOfZonesToFetch: Set<CKRecordZoneID>, completed:((ZonedSyncSummary) -> Void)) {
            
            self.recordZonesServerChangeTokens(forScope: scope) { (zoneIdTokenPairs) in
                
                let optionsByRecordZoneId: [CKRecordZoneID : CKFetchRecordZoneChangesOptions] = [:]
                
                // TODO: Scope metadata to user like other data so we can store server tokens for zones
                
                /*
                 for zoneIdTokenPair in zoneIdTokenPairs {
                 
                 let recordZoneID = CKRecordZoneID(
                 
                 let zoneChangesOptionsInstance = CKFetchRecordZoneChangesOptions()
                 zoneChangesOptionsInstance.previousServerChangeToken = zoneIdTokenPair.value
                 optionsByRecordZoneId[zoneIdTokenPair.key] = zoneChangesOptionsInstance
                 
                 }
                 */
                
                let changesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: Array(idsOfZonesToFetch), optionsByRecordZoneID: optionsByRecordZoneId)
                
                let changedRecords: CKRecordSet = CKRecordSet()
                var idsOfDeletedRecords: Set<CKRecordID> = []
                
                changesOperation.fetchAllChanges = true
                changesOperation.recordChangedBlock = { record in changedRecords.insert(record) }
                changesOperation.recordWithIDWasDeletedBlock = { (idOfDeletedRecord, string) in idsOfDeletedRecords.insert(idOfDeletedRecord) }
                changesOperation.recordZoneChangeTokensUpdatedBlock = { (recordZoneId, serverChangeToken, clientChangeTokenData) in
                    
                    // TODO: Scope metadata to user like other data so we can store server tokens for zones
                    
                    /*
                     if let serverChangeToken = serverChangeToken {
                     self.setServerChangeToken(serverChangeToken, forRecordZoneWithId: recordZoneId)
                     } else {
                     self.setServerChangeToken(nil, forRecordZoneWithId: recordZoneId)
                     }
                     */
                    
                }
                
                changesOperation.fetchRecordZoneChangesCompletionBlock = { error in
                    
                    guard error == nil else {
                        
                        completed(ZonedSyncSummary(result: .totalFailure, errors: [error!], idsOfRelevantRecords: []))
                        return
                        
                    }
                    
                    let recordIdentifiersForDeletedRecords = idsOfDeletedRecords.map({ $0.recordName }) as [RecordIdentifier]
                    
                    Mist.localDataCoordinator.retrieveRecords(
                        matching: { recordIdentifiersForDeletedRecords.contains($0.identifier) }, inStorageWithScope: scope, fetchDepth: -1,
                        retrievalCompleted: { (fetchOperationResult, records) in
                            
                            var recordIdsOfRecordsToRemove: [RecordIdentifier] = []
                            var recordsSetOfRecordsToRemove: Set<Record> = []
                            if let records = records {
                                recordIdsOfRecordsToRemove = records.map({ $0.identifier })
                                recordsSetOfRecordsToRemove = Set(records)
                            }
                            
                            guard fetchOperationResult.succeeded == true else {
                                
                                let errors = errorsArray(from: fetchOperationResult.error)
                                completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIdsOfRecordsToRemove))
                                
                                return
                                
                            }
                            
                            Mist.localDataCoordinator.removeRecords(recordsSetOfRecordsToRemove, fromStorageWith: scope, finished: { (removeOperationResult) in
                                
                                guard removeOperationResult.succeeded == true else {
                                    
                                    let errors = errorsArray(from: removeOperationResult.error)
                                    completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIdsOfRecordsToRemove))
                                    
                                    return
                                    
                                }
                                
                                var mistRecords: Set<Record> = []
                                
                                for changedCKRecord in changedRecords.records {
                                    
                                    let newMistRecord = Record(backingRemoteRecord: changedCKRecord)
                                    mistRecords.insert(newMistRecord)
                                    
                                }
                                
                                Mist.localDataCoordinator.addRecords(mistRecords, toStorageWith: scope, finished: { (addOperationResult) in
                                    
                                    let changedRecordsIds = changedRecords.recordIDs().map({ $0.recordName })
                                    
                                    guard addOperationResult.succeeded == true else {
                                        
                                        let errors = errorsArray(from: removeOperationResult.error)
                                        completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: changedRecordsIds))
                                        
                                        return
                                        
                                    }
                                    
                                    completed(ZonedSyncSummary(result: .success, errors: [], idsOfRelevantRecords: changedRecordsIds))
                                    
                                })
                                
                            })
                            
                    })
                    
                }
                
            }
            
        }
        
        self.databaseServerChangeToken(forScope: scope, retrievalCompleted: { (token) in
            
            let databaseChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)
            
            var idsOfZonesToFetch: Set<CKRecordZoneID> = []
            var idsOfZonesToDelete: Set<CKRecordZoneID> = []
            
            databaseChangesOperation.fetchAllChanges = true
            databaseChangesOperation.recordZoneWithIDChangedBlock = { recordZoneId in idsOfZonesToFetch.insert(recordZoneId) }
            databaseChangesOperation.recordZoneWithIDWasDeletedBlock = { recordZoneId in idsOfZonesToDelete.insert(recordZoneId) }
            databaseChangesOperation.changeTokenUpdatedBlock = { self.setDatabaseServerChangeToken($0, forScope: scope) }
            
            databaseChangesOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) in
                
                guard error == nil else {
                    completed(ZoneBasedDirectionalSyncSummary(result: .totalFailure, errors: [error!], zoneChangeSummary: nil, zoneDeletionSummary: nil))
                    return
                }
                
                if let newToken = newToken {
                    self.setDatabaseServerChangeToken(newToken, forScope: scope)
                }
                
                deleteInvalidatedZones(forZonesWithIds: idsOfZonesToDelete, completed: { (zonedDeletionSummary) in
                    
                    guard zonedDeletionSummary.result == .success else {
                        
                        completed(ZoneBasedDirectionalSyncSummary(
                            result: .totalFailure, errors: zonedDeletionSummary.errors, zoneChangeSummary: nil, zoneDeletionSummary: zonedDeletionSummary
                        ))
                        
                        return
                        
                    }
                    
                    fetchZoneChanges(forZonesWithIds: idsOfZonesToFetch, completed: { (zonedChangesSummary) in
                        
                        guard zonedChangesSummary.result == .success else {
                            
                            completed(ZoneBasedDirectionalSyncSummary(
                                result: .totalFailure, errors: zonedChangesSummary.errors, zoneChangeSummary: zonedChangesSummary, zoneDeletionSummary: zonedDeletionSummary
                            ))
                            
                            return
                            
                        }
                        
                        completed(ZoneBasedDirectionalSyncSummary(
                            result: .success, errors: [], zoneChangeSummary: zonedChangesSummary, zoneDeletionSummary: zonedDeletionSummary
                        ))
                        
                    })
                    
                })
                
            }
            
            let database = self.database(forScope: scope)
            database.add(databaseChangesOperation)
            
            
        })
        
    }
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    func performPublicDatabasePush(_ completed:((DirectionalSyncSummary) -> Void)) {
        self.performDatabasePush(for: .public, completed: completed)
    }
    
    func performDatabasePush(for scope:CKDatabaseScope, completed:((DirectionalSyncSummary) -> Void)) {
        
        let unpushedChanges: Set<Record>
        let unpushedDeletions: Set<Record>
        
        switch scope {
            
        case .public:
            unpushedChanges = Mist.localCachedRecordChangesStorage.publicModifiedRecordsAwaitingPushToCloud
            unpushedDeletions = Mist.localCachedRecordChangesStorage.publicDeletedRecordsAwaitingPushToCloud
            
        default:
            
            guard let currentUserIdentifier = self.currentUser?.identifier else {
                
                let noCurrentUserError = ErrorStruct(
                    code: 401, title: "User Not Authenticated",
                    failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                    description: "Get the user to log in and try this request again."
                )
                
                completed(DirectionalSyncSummary(result: .totalFailure, error: noCurrentUserError.errorObject()))
                
                return
                
            }
            
            unpushedChanges = Mist.localCachedRecordChangesStorage.userModifiedRecordsAwaitingPushToCloud(identifiedBy: currentUserIdentifier, inScope: scope)
            unpushedDeletions = Mist.localCachedRecordChangesStorage.userDeletedRecordsAwaitingPushToCloud(identifiedBy: currentUserIdentifier, inScope: scope)
            
        }
        
        let unpushedChangesCKRecords = unpushedChanges.map({ $0.backingRemoteRecord })
        let unpushedDeletionsCKRecordIDs = unpushedDeletions.map({ CKRecordID(recordName: $0.identifier) })
        
        
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: unpushedChangesCKRecords, recordIDsToDelete: unpushedDeletionsCKRecordIDs)
        modifyOperation.modifyRecordsCompletionBlock = { (savedRecords, recordIDsOfDeletedRecords, operationError) in

            guard operationError == nil else {
                
                completed(DirectionalSyncSummary(result: .totalFailure, error: operationError!))
                return
                
            }
            
            
            var idsOfRecordsChanged: [RecordIdentifier] = []
            if let savedRecords = savedRecords {
                idsOfRecordsChanged = savedRecords.map({ $0.recordID.recordName })
            }
            
            var idsOfRecordsDeleted: [RecordIdentifier] = []
            if let recordIDsOfDeletedRecords = recordIDsOfDeletedRecords {
                idsOfRecordsDeleted = recordIDsOfDeletedRecords.map({ $0.recordName })
            }
            
            completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: idsOfRecordsChanged, idsOfRecordsDeleted: idsOfRecordsDeleted))

        }
        
        let database = self.database(forScope: scope)
        database.add(modifyOperation)
        
    }
    
}

