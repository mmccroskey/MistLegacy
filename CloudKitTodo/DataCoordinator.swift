//
//  DataCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

typealias RefreshCompletion = (([CKDatabaseScope:Bool], Bool, Error?) -> Void)

private enum RecordChangeType {
    case addition
    case removal
}

class DataCoordinator {
    
    
    // MARK: - Singleton Instance
    
    static let shared = DataCoordinator()
    
    
    // MARK: - Initializer
    
    init() {
        
        let typeString = String(describing: DataCoordinator.type())
        guard typeString != "DataCoordinator" else {
            fatalError("DataCoordinator is an abstract class; it must not be directly instantiated.")
        }
        
        self.localRecordStorage = self.defaultStorage
        self.localMetadataStorage = self.defaultStorage
        self.localCachedRecordChangesStorage = self.defaultStorage
        
        self.operationQueue.maxConcurrentOperationCount = 1
        self.operationQueue.qualityOfService = .userInteractive
        
    }
    
    
    // MARK: - Public Properties
    
    let defaultStorage: InMemoryStorage = InMemoryStorage()
    
    var localRecordStorage: LocalRecordStorage
    var localMetadataStorage: LocalMetadataStorage
    var localCachedRecordChangesStorage: LocalCachedRecordChangesStorage
    
    
    // MARK: - Fetching Locally-Cached Items
    
    func retrieveRecord(matching identifier:RecordIdentifier, retrievalCompleted:((Record?) -> Void)) {
        
        var record: Record? = nil
        let execution = { record = self.localRecordStorage.record(matching: identifier) }
        let completion = { retrievalCompleted(record) }
        
        self.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching filter:((Record) throws -> Bool), retrievalCompleted:(([Record], Error?) -> Void)) {
        
        var records: [Record] = []
        var error: Error?
        
        let execution = {
            
            do {
                
                try records = self.localRecordStorage.records(matching: filter)
                
            } catch let fetchError {
                
                error = fetchError
                
            }
        
        }
        
        let completion = { retrievalCompleted(records, error) }
        
        self.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching predicate:NSPredicate, retrievalCompleted:(([Record]) -> Void)) {
        
        var records: [Record] = []
        let execution = { records = self.localRecordStorage.records(matching: predicate) }
        let completion = { retrievalCompleted(records) }
        
        self.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:Record) {
        self.addRecords(Set([record]))
    }
    
    func addRecords(_ records:Set<Record>) {
        self.performChange(ofType: .addition, on: records)
    }
    
    func removeRecord(_ record:Record) {
        self.removeRecords(Set([record]))
    }
    
    func removeRecords(_ records:Set<Record>) {
        self.performChange(ofType: .removal, on: records)
    }
    
    private func performChange(ofType changeType:RecordChangeType, on records:Set<Record>) {
        
        let execution = {
            
            for record in records {
                
                switch changeType {
                    
                case .addition:
                    self.localRecordStorage.addRecord(record)
                    self.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.insert(record)
                    
                case .removal:
                    self.localRecordStorage.removeRecord(record)
                    self.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud.insert(record)
                    self.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.remove(record)
                    
                }
                
            }
            
        }
        
        self.addOperation(withExecutionBlock: execution)
        
    }
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performCloudRefreshOfPublicData(inZone zone:CKRecordZone, completion:RefreshCompletion) {}
    
    func performCloudRefreshOfAllPrivateData(_ completion:RefreshCompletion) {}
    
    func performCloudRefreshOfPrivateObjectSubtree(originatingWith rootObject:Record, completion:RefreshCompletion) {}
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    func pushLocalChanges(_ completion:RefreshCompletion) {
        
        let scopes: [CKDatabaseScope] = [.public, .shared, .private]
        
        let unpushedChanges = self.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud
        let unpushedDeletions = self.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud
        
        var unpushedChangesDictionary: [CKDatabaseScope : [CKRecord]] = [:]
        var idsOfUnpushedDeletionsDictionary: [CKDatabaseScope : [CKRecordID]] = [:]
        
        // Gather up all the unpushed changes and deletions and group them by database scope
        var counter = 0
        while counter < scopes.count {
            
            let scope = scopes[counter]
            
            let unpushedChangesForCurrentAccessibility = unpushedChanges.filter({ $0.accessibility == scope }).map({ $0.backingRemoteRecord })
            unpushedChangesDictionary[scope] = unpushedChangesForCurrentAccessibility
            
            let idsOfUnpushedDeletionsForCurrentAccessibility = unpushedDeletions.filter({ $0.accessibility == scope }).map({ CKRecordID(recordName: $0.identifier) })
            idsOfUnpushedDeletionsDictionary[scope] = idsOfUnpushedDeletionsForCurrentAccessibility
            
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
    
    
    // MARK: - Private Properties
    
    private let operationQueue = OperationQueue()
    
    
    // MARK: - Private Functions
    
    private static func type() -> DataCoordinator.Type {
        return self
    }
    
    private func addOperation(withExecutionBlock block:(() -> Void), completionBlock:(() -> Void)?=nil) {
        
        let operation = BlockOperation { block() }
        operation.completionBlock = completionBlock
        
        if let latestOperation = self.operationQueue.operations.last {
            operation.addDependency(latestOperation)
        }
        
        self.operationQueue.addOperation(operation)
        
    }
    
}
