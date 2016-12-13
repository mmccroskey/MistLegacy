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
    
    private let localCacheCoordinator = LocalCacheCoordinator()
    private var currentUserCache: UserCache {
        
        guard let currentUser = Mist.currentUser else {
            
            fatalError(
                "We should never be calling currentUserCache when currentUser is nil, " +
                    "because all calls to this function should occur after guards for the  " +
                "existence of currentUser."
            )
            
        }
        
        return self.localCacheCoordinator.userCache(associatedWith: currentUser.identifier)
        
    }
    
    private enum RecordChangeType {
        case addition
        case removal
    }
    
    
    // MARK: - Fetching Locally-Cached Items
    
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
    
    func userRecordExists(withIdentifier identifier:RecordIdentifier, finished:((Record?) -> Void)) {
        
        let cacheForUserRecord = self.localCacheCoordinator.userCache(associatedWith: identifier)
        
        if let userRecord = cacheForUserRecord.publicCache.cachedRecords[identifier] {
            finished(userRecord)
        } else {
            finished(nil)
        }
        
    }
    
    func retrieveRecord(
        matching identifier:RecordIdentifier, fromStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, Record?) -> Void)) {
        
        var result: RecordOperationResult? = nil
        var record: Record? = nil
        
        let execution = {
            
            record = self.currentUserCache.scopedCache(withScope: scope).cachedRecords[identifier]
            
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
        withType type:Record.Type?=nil, matching filter:((Record) throws -> Bool), inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        let typeFilter: ((Record) throws -> Bool)?
        if let type = type {
            let typeString = String(describing: type)
            typeFilter = { $0.typeString == typeString }
        } else {
            typeFilter = nil
        }
        
        var success: Bool = true
        var error: Error?
        var records: [Record] = []
        
        let execution = {
            
            do {
                
                let initialRecords = try self.currentUserCache.scopedCache(withScope: scope).cachedRecords.values.filter(filter)
                
                let typeFilteredRecords: [Record]
                if let typeFilter = typeFilter {
                    typeFilteredRecords = try initialRecords.filter(typeFilter)
                } else {
                    typeFilteredRecords = initialRecords
                }
                
                records = typeFilteredRecords
                
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
        withType type:Record.Type?=nil, matching predicate:NSPredicate, inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        self.retrieveRecords(withType: type, matching: { predicate.evaluate(with: $0) }, inStorageWithScope: scope, fetchDepth: fetchDepth, retrievalCompleted: retrievalCompleted)
        
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
        
        guard records.count > 0 else {
            
            if let finished = finished {
                finished(RecordOperationResult(succeeded: true, error: nil))
            }
            
            return
            
        }
        
        var recordOperationResult: RecordOperationResult?
        
        let execution = {
            
            for record in records {
                
                switch changeType {
                    
                case .addition:
                    
                    guard ((record.scope == nil) || (record.scope == scope)) else {
                        fatalError("The Record cannot be saved to the \(scope) scope -- it's already saved in the \(record.scope) scope.")
                    }
                    
                    record.scope = scope
                    
                    if scope == .private && record.recordZone == nil {
                        
                        guard let currentUser = Mist.currentUser else {
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
                    
                    self.currentUserCache.scopedCache(withScope: scope).cachedRecords[record.identifier] = record
                    self.currentUserCache.scopedCache(withScope: scope).recordsWithUnpushedChanges[record.identifier] = record
                    
                case .removal:
                    
                    self.currentUserCache.scopedCache(withScope: scope).cachedRecords.removeValue(forKey: record.identifier)
                    self.currentUserCache.scopedCache(withScope: scope).recordsWithUnpushedChanges.removeValue(forKey: record.identifier)
                    
                    self.currentUserCache.scopedCache(withScope: scope).recordsWithUnpushedDeletions[record.identifier] = record
                    
                }
                
            }
            
            if recordOperationResult == nil {
                recordOperationResult = RecordOperationResult(succeeded: true, error: nil)
            }
            
        }
        
        let completion = {
            
            guard let recordOperationResult = recordOperationResult else {
                fatalError("recordOperationResult should have been set to a value in the execution block above.")
            }
            
            if let finished = finished {
                finished(recordOperationResult)
            }
            
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
}
