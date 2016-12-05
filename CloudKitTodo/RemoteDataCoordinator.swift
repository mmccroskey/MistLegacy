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
            
            guard error == nil else {
                completion(SyncStepResult(success: false, error: error!))
                return
            }
            
            // TODO: Handle case where User has changed
            let user = CloudKitUser(backingRemoteRecord: record)
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
        
        // TODO: Actually pull data matching descriptors
        completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: [], idsOfRecordsDeleted: []))
        
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
                            
                            var recordIds: [RecordIdentifier] = []
                            var recordsSet: Set<Record> = []
                            if let records = records {
                                recordIds = records.map({ $0.identifier })
                                recordsSet = Set(records)
                            }
                            
                            guard fetchOperationResult.succeeded == true else {
                                
                                let errors = errorsArray(from: fetchOperationResult.error)
                                completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                                
                                return
                                
                            }
                            
                            Mist.localDataCoordinator.removeRecords(recordsSet, fromStorageWith: scope, finished: { (removeOperationResult) in
                                
                                let recordIds = recordsSet.map({ $0.identifier })
                                
                                guard removeOperationResult.succeeded == true else {
                                    
                                    let errors = errorsArray(from: removeOperationResult.error)
                                    completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                                    
                                    return
                                    
                                }
                                
                                completed(ZonedSyncSummary(result: .success, errors:[], idsOfRelevantRecords: recordIds))
                                
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
        
        // TODO: Actually push data
        completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: [], idsOfRecordsDeleted: []))
        
    }
    
    func performDatabasePush(for scope:CKDatabaseScope, completed:((DirectionalSyncSummary) -> Void)) {
        
    }
    
    func pushLocalChanges(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        
        
        //        let scopes: [CKDatabaseScope] = [.public, .shared, .private]
        //
        //        let unpushedChanges = Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud
        //        let unpushedDeletions = Mist.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud
        //
        //        var unpushedChangesDictionary: [CKDatabaseScope : [CKRecord]] = [:]
        //        var idsOfUnpushedDeletionsDictionary: [CKDatabaseScope : [CKRecordID]] = [:]
        //
        //        // Gather up all the unpushed changes and deletions and group them by database scope
        //        var counter = 0
        //        while counter < scopes.count {
        //
        //            let scope = scopes[counter]
        //
        //            let unpushedChangesForCurrentScope = unpushedChanges.filter({ $0.scope == scope }).map({ $0.backingRemoteRecord })
        //            unpushedChangesDictionary[scope] = unpushedChangesForCurrentScope
        //
        //            let idsOfUnpushedDeletionsForCurrentScope = unpushedDeletions.filter({ $0.scope == scope }).map({ CKRecordID(recordName: $0.identifier) })
        //            idsOfUnpushedDeletionsDictionary[scope] = idsOfUnpushedDeletionsForCurrentScope
        //
        //            counter = counter + 1
        //
        //        }
        //
        //        var modifyOperations: [CKDatabaseScope : CKModifyRecordsOperation] = [:]
        //        var finishedStates: [CKDatabaseScope : Bool] = [
        //
        //            .public : false,
        //            .shared : false,
        //            .private : false
        //
        //        ]
        //
        //        // Create a modify operation for each database scope
        //        for scope in scopes {
        //
        //            let recordsToSave = unpushedChangesDictionary[scope]
        //            let recordIdsToDelete = idsOfUnpushedDeletionsDictionary[scope]
        //
        //            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIdsToDelete)
        //            modifyOperation.modifyRecordsCompletionBlock = { (savedRecords, recordIDsOfDeletedRecords, operationError) in
        //
        //                // Mark this database's modify operation as complete
        //                finishedStates[scope] = true
        //
        //                // If there's an error, then return it and bail out of everything
        //                // (since the operations have a linear dependency, bailing out of
        //                // a particular operation bails out of any that follow)
        //                if let operationError = operationError {
        //                    completion(finishedStates, false, operationError)
        //                    return
        //                }
        //
        //                // If this is the last of the three operations
        //                if scope == .private {
        //                    completion(finishedStates, true, nil)
        //                }
        //
        //            }
        //
        //        }
        //
        //        func dictionaryKeysMismatchFatalError(_ name:String, dictionary:[CKDatabaseScope:Any]) -> Never {
        //
        //            fatalError(
        //                "The keys for the \(name) dictionary and the scopes dictionary must match, " +
        //                    "but they don't. Here are those dictionaries:\n" +
        //                    "\(name): \(dictionary)\n" +
        //                    "scopes: \(scopes)\n"
        //            )
        //
        //        }
        //
        //        // Make each modify operation dependent upon the previous database scope
        //        counter = (scopes.count - 1)
        //        while counter > 0 {
        //
        //            let currentScope = scopes[counter]
        //            guard let currentModifyOperation = modifyOperations[currentScope] else {
        //                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
        //            }
        //
        //            let previousScope = scopes[counter - 1]
        //            guard let previousModifyOperation = modifyOperations[previousScope] else {
        //                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
        //            }
        //
        //            currentModifyOperation.addDependency(previousModifyOperation)
        //
        //            counter = counter - 1
        //
        //        }
        //
        //        let databases: [CKDatabaseScope : CKDatabase] = [
        //            
        //            .public : self.container.publicCloudDatabase,
        //            .shared : self.container.sharedCloudDatabase,
        //            .private : self.container.privateCloudDatabase
        //            
        //        ]
        //        
        //        // Add each modify operation to its respective database's operation queue
        //        for scope in scopes {
        //            
        //            guard let database = databases[scope] else {
        //                dictionaryKeysMismatchFatalError("databases", dictionary: databases)
        //            }
        //            
        //            guard let modifyOperation = modifyOperations[scope] else {
        //                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
        //            }
        //            
        //            database.add(modifyOperation)
        //            
        //        }
        
        
    }
    
}
