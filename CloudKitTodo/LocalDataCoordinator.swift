//
//  LocalDataCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/5/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

internal class LocalDataCoordinator : DataCoordinator {
    
    
    // MARK: - Private Properties
    
    // TODO: Implement code to keep this up to date
    private var currentUser: CloudKitUser? = CloudKitUser()
    
    private var publicRetrievedRecordsCache: [RecordIdentifier : Record] = [:]
    private var userRetrievedRecordsCache: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    
    private enum RecordChangeType {
        case addition
        case removal
    }
    
    
    // MARK: - Fetching Locally-Cached Items
    
    private func scopedRecordsCacheForUser(identifiedBy userRecordIdentifier:RecordIdentifier, withScope scope:StorageScope) -> [RecordIdentifier : Record] {
        
        guard scope != .public else {
            fatalError("Public records are not associated with a User before being added to the local record cache.")
        }
        
        let potentialExistingStorageForUser: [StorageScope : [RecordIdentifier : Record]]? = self.userRetrievedRecordsCache[userRecordIdentifier]
        
        var storageForUser: [StorageScope : [RecordIdentifier : Record]]
        if let existingStorageForUser = potentialExistingStorageForUser {
            storageForUser = existingStorageForUser
        } else {
            storageForUser = [:]
        }
        self.userRetrievedRecordsCache[userRecordIdentifier] = storageForUser
        
        let potentialScopedStorageForUser: [RecordIdentifier : Record]? = self.userRetrievedRecordsCache[userRecordIdentifier]?[scope]
        
        var scopedStorageForUser: [RecordIdentifier : Record]
        if let existingScopedStorageForUser = potentialScopedStorageForUser {
            scopedStorageForUser = existingScopedStorageForUser
        } else {
            scopedStorageForUser = [:]
        }
        
        return scopedStorageForUser
        
    }
    
    private func associateRelatedRecords(for record:Record?, in scope:StorageScope, using fetchDepth:Int, finished:((RecordOperationResult) -> Void)) {
        
        var success = true
        
        if let record = record, fetchDepth != 0 {
            
            for relatedRecordDataSetKeyPair in record.relatedRecordDataSetKeyPairs {
                
                let propertyName = relatedRecordDataSetKeyPair.key
                let identifier = relatedRecordDataSetKeyPair.value.identifier
                let action = relatedRecordDataSetKeyPair.value.action
                
                let newFetchDepth: Int
                if fetchDepth > 0 {
                    newFetchDepth = (fetchDepth - 1)
                } else {
                    newFetchDepth = fetchDepth
                }
                
                self.retrieveRecord(matching: identifier, fromStorageWithScope: scope, fetchDepth: newFetchDepth, retrievalCompleted: { (result, fetchedRecord) in
                    
                    guard success == true else {
                        return
                    }
                    
                    guard result.succeeded == true else {
                        
                        success = false
                        finished(result)
                        return
                        
                    }
                    
                    if let relatedRecord = fetchedRecord {
                        record.setRelatedRecord(relatedRecord, forKey: propertyName, withRelationshipDeleteBehavior: action)
                    }
                    
                })
                
            }
            
        } else {
            
            finished(RecordOperationResult(succeeded: true, error: nil))
            
        }
        
    }
    
    
    func retrieveRecord(
        matching identifier:RecordIdentifier, fromStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, Record?) -> Void)) {
        
        var result: RecordOperationResult? = nil
        var record: Record? = nil
        
        let execution = {
            
            if scope == .public {
                
                if let cachedRecord = self.publicRetrievedRecordsCache[identifier] {
                    
                    record = cachedRecord
                    
                } else {
                    
                    record = Mist.localRecordStorage.publicRecord(matching: identifier)
                    self.publicRetrievedRecordsCache[identifier] = record
                    
                }
                
            } else {
                
                guard let currentUserIdentifier = self.currentUser?.identifier else {
                    
                    let noCurrentUserError = ErrorStruct(
                        code: 401, title: "User Not Authenticated",
                        failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                        description: "Get the user to log in and try this request again."
                    )
                    
                    result = RecordOperationResult(succeeded: false, error: noCurrentUserError.errorObject())
                    return
                    
                }
                
                var userScopedRecordsCache = self.scopedRecordsCacheForUser(identifiedBy: currentUserIdentifier, withScope: scope)
                if let cachedRecord = userScopedRecordsCache[identifier] {
                    
                    record = cachedRecord
                    
                } else {
                    
                    record = Mist.localRecordStorage.userRecord(matching: identifier, identifiedBy: currentUserIdentifier, inScope: scope)
                    
                    userScopedRecordsCache[identifier] = record
                    self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = userScopedRecordsCache
                    
                }
                
            }
            
            self.associateRelatedRecords(for: record, in: scope, using: fetchDepth, finished: { (operationResult) in
                result = operationResult
            })
            
        }
        
        let completion = {
            
            guard let result = result else {
                fatalError("RecordOperationResult should have been set at this point.")
            }
            
            retrievalCompleted(result, record)
            
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(
        matching filter:((Record) throws -> Bool), inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        var success: Bool = true
        var error: Error?
        var records: [Record] = []
        
        let execution = {
            
            do {
                
                if scope == .public {
                    
                    let cachedRecords = try self.publicRetrievedRecordsCache.values.filter(filter)
                    if cachedRecords.count > 0 {
                        
                        records = cachedRecords
                        
                    } else {
                        
                        try records = Mist.localRecordStorage.publicRecords(matching: filter)
                        
                        for record in records {
                            self.publicRetrievedRecordsCache[record.identifier] = record
                        }
                        
                    }
                    
                } else {
                    
                    guard let currentUserIdentifier = self.currentUser?.identifier else {
                        
                        let noCurrentUserError = ErrorStruct(
                            code: 401, title: "User Not Authenticated",
                            failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                            description: "Get the user to log in and try this request again."
                        )
                        
                        success = false
                        error = noCurrentUserError.errorObject()
                        
                        return
                        
                    }
                    
                    
                    var userScopedRecordsCache = self.scopedRecordsCacheForUser(identifiedBy: currentUserIdentifier, withScope: scope)
                    let cachedRecords = try userScopedRecordsCache.values.filter(filter)
                    if cachedRecords.count > 0 {
                        
                        records = cachedRecords
                        
                    } else {
                        
                        try records = Mist.localRecordStorage.userRecords(matching: filter, identifiedBy: currentUserIdentifier, inScope: scope)
                        
                        for record in records {
                            userScopedRecordsCache[record.identifier] = record
                        }
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = userScopedRecordsCache
                        
                    }
                    
                }
                
                for record in records {
                    
                    self.associateRelatedRecords(for: record, in: scope, using: fetchDepth, finished: { (operationResult) in
                        
                        guard operationResult.succeeded == true else {
                            
                            success = false
                            error = operationResult.error
                            
                            return
                            
                        }
                        
                    })
                    
                }
                
            } catch let fetchError {
                
                error = fetchError
                
            }
            
        }
        
        let completion = {
            
            let result = RecordOperationResult(succeeded: success, error: error)
            retrievalCompleted(result, records)
            
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(
        matching predicate:NSPredicate, inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        self.retrieveRecords(matching: { predicate.evaluate(with: $0) }, inStorageWithScope: scope, fetchDepth: fetchDepth, retrievalCompleted: retrievalCompleted)
        
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:Record, toStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.addRecords(Set([record]), toStorageWith: scope, finished: finished)
    }
    
    func addRecords(_ records:Set<Record>, toStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.performChange(ofType: .addition, on: records, within: scope, finished: finished)
    }
    
    func removeRecord(_ record:Record, fromStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.removeRecords(Set([record]), fromStorageWith: scope, finished: finished)
    }
    
    func removeRecords(_ records:Set<Record>, fromStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.performChange(ofType: .removal, on: records, within: scope, finished: finished)
    }
    
    private func performChange(ofType changeType:RecordChangeType, on records:Set<Record>, within scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        if scope == .private || scope == .shared {
            
            guard self.currentUser != nil else {
                
                let noCurrentUserError = ErrorStruct(
                    code: 401, title: "User Not Authenticated",
                    failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                    description: "Get the user to log in and try this request again."
                )
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
        }
        
        var recordOperationResult: RecordOperationResult?
        
        Mist.localRecordsQueue.addOperation {
            
            for record in records {
                
                switch changeType {
                    
                case .addition:
                    
                    guard ((record.scope == nil) || (record.scope == scope)) else {
                        fatalError("The Record cannot be saved to the \(scope) scope -- it's already saved in the \(record.scope) scope.")
                    }
                    
                    record.scope = scope
                    
                    if scope == .private && record.recordZone == nil {
                        
                        guard let currentUser = self.currentUser else {
                            fatalError("We're trying to create a zone with the current User as the User, but no current User exists.")
                        }
                        
                        let recordZoneID = CKRecordZoneID(zoneName: UUID().uuidString, ownerName: currentUser.identifier)
                        let recordZone = CKRecordZone(zoneID: recordZoneID)
                        record.recordZone = recordZone
                        
                    }
                    
                    switch scope {
                        
                    case .public:
                        
                        guard record.recordZone == nil else {
                            fatalError("Records with custom zones cannot be added to the public scope; the public scope doesn't support custom zones.")
                        }
                        
                        guard record.share == nil else {
                            fatalError("Records with associated shares cannot be added to the public scope; the public scope doesn't support shares.")
                        }
                        
                    case .shared:
                        
                        guard record.share != nil || record.parent != nil else {
                            fatalError("Every Record stored in the shared scope must have an associated share, or a parent, or both.")
                        }
                        
                    case .private:
                        break
                        
                    }
                    
                    let relatedRecords = Set(record.relatedRecordsCache.values)
                    let children = record.children
                    let associatedRecords = relatedRecords.union(children)
                    for associatedRecord in associatedRecords {
                        
                        Record.ensureDatabasesAndRecordZonesMatch(between: record, and: associatedRecord)
                        
                        let identifier = associatedRecord.identifier
                        
                        self.retrieveRecord(matching: identifier, fromStorageWithScope: scope, fetchDepth: -1, retrievalCompleted: { (result, record) in
                            
                            guard result.succeeded == true else {
                                
                                if recordOperationResult == nil {
                                    recordOperationResult = result
                                }
                                
                                return
                                
                            }
                            
                            if record == nil {
                                
                                self.addRecord(associatedRecord, toStorageWith: scope, finished: { (associatedRecordResult) in
                                    
                                    guard associatedRecordResult.succeeded == true else {
                                        
                                        if recordOperationResult == nil {
                                            recordOperationResult = associatedRecordResult
                                        }
                                        
                                        return
                                        
                                    }
                                    
                                })
                                
                            }
                            
                        })
                        
                    }
                    
                    if scope == .public {
                        
                        self.publicRetrievedRecordsCache[record.identifier] = record
                        Mist.localRecordStorage.addPublicRecord(record)
                        
                        Mist.localCachedRecordChangesStorage.publicModifiedRecordsAwaitingPushToCloud.insert(record)
                        
                    } else {
                        
                        let currentUserIdentifier = self.currentUser!.identifier
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = [record.identifier : record]
                        Mist.localRecordStorage.addUserRecord(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        
                        Mist.localCachedRecordChangesStorage.addUserModifiedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        
                    }
                    
                case .removal:
                    
                    if scope == .public {
                        
                        self.publicRetrievedRecordsCache.removeValue(forKey: record.identifier)
                        Mist.localRecordStorage.removePublicRecord(record)
                        
                        Mist.localCachedRecordChangesStorage.publicDeletedRecordsAwaitingPushToCloud.insert(record)
                        Mist.localCachedRecordChangesStorage.publicModifiedRecordsAwaitingPushToCloud.remove(record)
                        
                    } else {
                        
                        let currentUserIdentifier = self.currentUser!.identifier
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]!.removeValue(forKey: record.identifier)
                        Mist.localRecordStorage.removeUserRecord(matching: record.identifier, identifiedBy: currentUserIdentifier, fromScope: scope)
                        
                        Mist.localCachedRecordChangesStorage.addUserDeletedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        Mist.localCachedRecordChangesStorage.removeUserModifiedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, fromScope: scope)
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
}
