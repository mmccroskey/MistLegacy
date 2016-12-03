//
//  Mist.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit



typealias StorageScope = CKDatabaseScope

typealias RefreshCompletion = (([StorageScope:Bool], Bool, Error?) -> Void)



// MARK: -



class Mist {
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, from:StorageScope, fetchDepth:Int = -1, finished:((Record?) -> Void)) {
        self.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWith: from, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(where filter:((Record) throws -> Bool), within:StorageScope, fetchDepth:Int = -1, finished:(([Record], Error?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: filter, inStorageWith: within, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(where predicate:NSPredicate, within:StorageScope, fetchDepth:Int = -1, finished:(([Record]) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: predicate, inStorageWith: within, fetchDepth:fetchDepth, retrievalCompleted: finished)
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record, to:StorageScope) {
        self.localDataCoordinator.addRecord(record, toStorageWith: to)
    }
    
    static func add(_ records:Set<Record>, to:StorageScope) {
        self.localDataCoordinator.addRecords(records, toStorageWith: to)
    }
    
    static func remove(_ record:Record, from:StorageScope) {
        self.localDataCoordinator.removeRecord(record, fromStorageWith: from)
    }
    
    static func remove(_ records:Set<Record>, from:StorageScope) {
        self.localDataCoordinator.removeRecords(records, fromStorageWith: from)
    }
    
    
    // MARK: - Syncing Items
    
    static func sync(_ finished:((Bool, Error?) -> Void)) {
        
        
        
    }
    
    
    // MARK: - Configuration Properties
    
    static var localRecordStorage: LocalRecordStorage = InMemoryStorage()
    static var localMetadataStorage: LocalMetadataStorage = InMemoryStorage()
    static var localCachedRecordChangesStorage: LocalCachedRecordChangesStorage = InMemoryStorage()
    
    
    // MARK: - Internal Properties
    
    internal static let localRecordsQueue = Queue()
    internal static let localMetadataQueue = Queue()
    internal static let localCachedRecordChangesQueue = Queue()
    
    
    // MARK: - Private Properties
    
    private static let localDataCoordinator = LocalDataCoordinator()
    private static let remoteDataCoordinator = RemoteDataCoordinator()
    
}



// MARK: - 



internal class Queue {
    
    
    // MARK: - Initializer
    
    init() {
        
        self.operationQueue.maxConcurrentOperationCount = 1
        self.operationQueue.qualityOfService = .userInteractive
        
    }
    
    
    // MARK: - Private Properties
    
    private let operationQueue = OperationQueue()
    
    
    // MARK: - Public Functions
    
    func addOperation(withExecutionBlock block:(() -> Void), completionBlock:(() -> Void)?=nil) {
        
        let operation = BlockOperation { block() }
        operation.completionBlock = completionBlock
        
        if let latestOperation = self.operationQueue.operations.last {
            operation.addDependency(latestOperation)
        }
        
        self.operationQueue.addOperation(operation)
        
    }
    
}



// MARK: -


private class LocalDataCoordinator {
    
    
    // MARK: - Private Properties
    
    private var retrievedRecordsCache: [RecordIdentifier : Record] = [:]
    
    private enum RecordChangeType {
        case addition
        case removal
    }
    
    
    // MARK: - Fetching Locally-Cached Items
    
    func retrieveRecord(matching identifier:RecordIdentifier, fromStorageWith scope:StorageScope, fetchDepth:Int, retrievalCompleted:((Record?) -> Void)) {
        
        var record: Record? = nil
        
        let execution = {
            
            if let cachedRecord = self.retrievedRecordsCache[identifier] {
                
                record = cachedRecord
                
            } else {
                
                record = Mist.localRecordStorage.record(matching: identifier, inStorageWith: scope)
                self.retrievedRecordsCache[identifier] = record
                
            }
            
            self.associateRelatedRecords(for: record, in: scope, using: fetchDepth)
            
        }
        
        let completion = { retrievalCompleted(record) }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching filter:((Record) throws -> Bool), inStorageWith scope:StorageScope, fetchDepth:Int, retrievalCompleted:(([Record], Error?) -> Void)) {
        
        var records: [Record] = []
        var error: Error?
        
        let execution = {
            
            do {
                
                let cachedRecords = try self.retrievedRecordsCache.values.filter(filter)
                if cachedRecords.count > 0 {
                    
                    records = cachedRecords
                    
                } else {
                    
                    try records = Mist.localRecordStorage.records(matching: filter, inStorageWith: scope)
                    
                    for record in records {
                        self.retrievedRecordsCache[record.identifier] = record
                    }
                    
                }
                
                for record in records {
                    self.associateRelatedRecords(for: record, in: scope, using: fetchDepth)
                }
                
            } catch let fetchError {
                
                error = fetchError
                
            }
            
        }
        
        let completion = { retrievalCompleted(records, error) }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching predicate:NSPredicate, inStorageWith scope:StorageScope, fetchDepth:Int, retrievalCompleted:(([Record]) -> Void)) {
        
        var records: [Record] = []
        
        let execution = {
            
            let cachedRecords = self.retrievedRecordsCache.values.filter({ predicate.evaluate(with: $0) }) as [Record]
            if cachedRecords.count > 0 {
                
                records = cachedRecords
                
            } else {
                
                records = Mist.localRecordStorage.records(matching: predicate, inStorageWith: scope)
                
                for record in records {
                    self.retrievedRecordsCache[record.identifier] = record
                }
                
            }
            
            for record in records {
                self.associateRelatedRecords(for: record, in: scope, using: fetchDepth)
            }
            
        }
        
        let completion = { retrievalCompleted(records) }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    private func associateRelatedRecords(for record:Record?, in scope:StorageScope, using fetchDepth:Int) {
        
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
                
                self.retrieveRecord(matching: identifier, fromStorageWith: scope, fetchDepth: newFetchDepth, retrievalCompleted: { (fetchedRecord) in
                    
                    if let relatedRecord = fetchedRecord {
                        record.setRelatedRecord(relatedRecord, forKey: propertyName, withRelationshipDeleteBehavior: action)
                    }
                    
                })
                
            }
            
        }
        
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:Record, toStorageWith scope:StorageScope) {
        self.addRecords(Set([record]), toStorageWith: scope)
    }
    
    func addRecords(_ records:Set<Record>, toStorageWith scope:StorageScope) {
        self.performChange(ofType: .addition, on: records, within: scope)
    }
    
    func removeRecord(_ record:Record, fromStorageWith scope:StorageScope) {
        self.removeRecords(Set([record]), fromStorageWith: scope)
    }
    
    func removeRecords(_ records:Set<Record>, fromStorageWith scope:StorageScope) {
        self.performChange(ofType: .removal, on: records, within: scope)
    }
    
    private func performChange(ofType changeType:RecordChangeType, on records:Set<Record>, within scope:StorageScope) {
        
        let execution = {
            
            for record in records {
                
                switch changeType {
                    
                case .addition:
                    
                    guard ((record.scope == nil) || (record.scope == scope)) else {
                        fatalError("The Record cannot be saved to storage with scope \(scope) -- it's already saved in storage with scope \(record.scope).")
                    }
                    
                    record.scope = scope
                    
                    let relatedRecords = Set(record.relatedRecordsCache.values)
                    let children = record.children
                    let associatedRecords = relatedRecords.union(children)
                    for associatedRecord in associatedRecords {
                        
                        Record.ensureDatabasesAndRecordZonesMatch(between: record, and: associatedRecord)
                        
                        let identifier = associatedRecord.identifier
                        self.retrieveRecord(matching: identifier, fromStorageWith: scope, fetchDepth: -1, retrievalCompleted: { (record) in
                            
                            if record == nil {
                                self.addRecord(associatedRecord, toStorageWith: scope)
                            }
                            
                        })
                        
                    }
                    
                    self.retrievedRecordsCache[record.identifier] = record
                    Mist.localRecordStorage.addRecord(record, toStorageWith: scope)
                    Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.insert(record)
                    
                case .removal:
                    
                    self.retrievedRecordsCache.removeValue(forKey: record.identifier)
                    Mist.localRecordStorage.removeRecord(record, fromStorageWith: scope)
                    Mist.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud.insert(record)
                    Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.remove(record)
                    
                }
                
            }
            
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution)
        
    }
    
    
    // MARK: - Private Functions
    
    private func metadata(forKey key:String) -> Any? {
        
        if let selfMetadata = Mist.localMetadataStorage.value(forKey: "LocalDataCoordinator") as? [String : Any?] {
            return selfMetadata[key]
        }
        
        return nil
        
    }
    
    private func setMetadata(_ metadata:Any?, forKey key:String) {
        
        if var selfMetadata = Mist.localMetadataStorage.value(forKey: "LocalDataCoordinator") as? [String : Any?] {
            
            selfMetadata[key] = metadata
            Mist.localMetadataStorage.setValue(selfMetadata, forKey: "LocalDataCoordinator")
            
        }
        
    }
    
}



// MARK: - 



private class RemoteDataCoordinator {
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performCloudRefreshOfPublicData(inZone zone:CKRecordZone, completion:RefreshCompletion) {}
    
    func performCloudRefreshOfAllPrivateData(_ completion:RefreshCompletion) {}
    
    func performCloudRefreshOfPrivateObjectSubtree(originatingWith rootObject:Record, completion:RefreshCompletion) {}
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    func pushLocalChanges(_ completion:RefreshCompletion) {
        
        let scopes: [CKDatabaseScope] = [.public, .shared, .private]
        
        let unpushedChanges = Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud
        let unpushedDeletions = Mist.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud
        
        var unpushedChangesDictionary: [CKDatabaseScope : [CKRecord]] = [:]
        var idsOfUnpushedDeletionsDictionary: [CKDatabaseScope : [CKRecordID]] = [:]
        
        // Gather up all the unpushed changes and deletions and group them by database scope
        var counter = 0
        while counter < scopes.count {
            
            let scope = scopes[counter]
            
            let unpushedChangesForCurrentScope = unpushedChanges.filter({ $0.scope == scope }).map({ $0.backingRemoteRecord })
            unpushedChangesDictionary[scope] = unpushedChangesForCurrentScope
            
            let idsOfUnpushedDeletionsForCurrentScope = unpushedDeletions.filter({ $0.scope == scope }).map({ CKRecordID(recordName: $0.identifier) })
            idsOfUnpushedDeletionsDictionary[scope] = idsOfUnpushedDeletionsForCurrentScope
            
            counter = counter + 1
            
        }
        
        var modifyOperations: [CKDatabaseScope : CKModifyRecordsOperation] = [:]
        var finishedStates: [CKDatabaseScope : Bool] = [
            
            .public : false,
            .shared : false,
            .private : false
            
        ]
        
        // Create a modify operation for each database scope
        for scope in scopes {
            
            let recordsToSave = unpushedChangesDictionary[scope]
            let recordIdsToDelete = idsOfUnpushedDeletionsDictionary[scope]
            
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIdsToDelete)
            modifyOperation.modifyRecordsCompletionBlock = { (savedRecords, recordIDsOfDeletedRecords, operationError) in
                
                // Mark this database's modify operation as complete
                finishedStates[scope] = true
                
                // If there's an error, then return it and bail out of everything
                // (since the operations have a linear dependency, bailing out of
                // a particular operation bails out of any that follow)
                if let operationError = operationError {
                    completion(finishedStates, false, operationError)
                    return
                }
                
                // If this is the last of the three operations
                if scope == .private {
                    completion(finishedStates, true, nil)
                }
                
            }
            
        }
        
        func dictionaryKeysMismatchFatalError(_ name:String, dictionary:[CKDatabaseScope:Any]) -> Never {
            
            fatalError(
                "The keys for the \(name) dictionary and the scopes dictionary must match, " +
                    "but they don't. Here are those dictionaries:\n" +
                    "\(name): \(dictionary)\n" +
                    "scopes: \(scopes)\n"
            )
            
        }
        
        // Make each modify operation dependent upon the previous database scope
        counter = (scopes.count - 1)
        while counter > 0 {
            
            let currentScope = scopes[counter]
            guard let currentModifyOperation = modifyOperations[currentScope] else {
                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
            }
            
            let previousScope = scopes[counter - 1]
            guard let previousModifyOperation = modifyOperations[previousScope] else {
                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
            }
            
            currentModifyOperation.addDependency(previousModifyOperation)
            
            counter = counter - 1
            
        }
        
        let container = CKContainer.default()
        let databases: [CKDatabaseScope : CKDatabase] = [
            
            .public : container.publicCloudDatabase,
            .shared : container.sharedCloudDatabase,
            .private : container.privateCloudDatabase
            
        ]
        
        // Add each modify operation to its respective database's operation queue
        for scope in scopes {
            
            guard let database = databases[scope] else {
                dictionaryKeysMismatchFatalError("databases", dictionary: databases)
            }
            
            guard let modifyOperation = modifyOperations[scope] else {
                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
            }
            
            database.add(modifyOperation)
            
        }
        
        
    }
    
    
    // MARK: Private Functions
    
    private func metadata(forKey key:String) -> Any? {
        
        if let selfMetadata = Mist.localMetadataStorage.value(forKey: "RemoteDataCoordinator") as? [String : Any?] {
            return selfMetadata[key]
        }
        
        return nil
        
    }
    
    private func setMetadata(_ metadata:Any?, forKey key:String) {
        
        if var selfMetadata = Mist.localMetadataStorage.value(forKey: "RemoteDataCoordinator") as? [String : Any?] {
            
            selfMetadata[key] = metadata
            Mist.localMetadataStorage.setValue(selfMetadata, forKey: "RemoteDataCoordinator")
            
        }
        
    }
    
}


