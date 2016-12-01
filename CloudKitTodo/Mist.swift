//
//  Mist.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit



typealias RefreshCompletion = (([CKDatabaseScope:Bool], Bool, Error?) -> Void)



// MARK: -



class Mist {
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, finished:((Record?) -> Void)) {
        self.localDataCoordinator.retrieveRecord(matching: identifier, retrievalCompleted: finished)
    }
    
    static func find(where filter:((Record) throws -> Bool), finished:(([Record], Error?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: filter, retrievalCompleted: finished)
    }
    
    static func find(where predicate:NSPredicate, finished:(([Record]) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: predicate, retrievalCompleted: finished)
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record) {
        self.localDataCoordinator.addRecord(record)
    }
    
    static func add(_ records:Set<Record>) {
        self.localDataCoordinator.addRecords(records)
    }
    
    static func delete(_ record:Record) {
        self.localDataCoordinator.removeRecord(record)
    }
    
    static func delete(_ records:Set<Record>) {
        self.localDataCoordinator.removeRecords(records)
    }
    
    
    // MARK: - Configuration Properties
    
    static var localRecordStorage: LocalRecordStorage = InMemoryStorage()
    static var localMetadataStorage: LocalMetadataStorage = InMemoryStorage()
    static var localCachedRecordChangesStorage: LocalCachedRecordChangesStorage = InMemoryStorage()
    
    
    // MARK: - Protected Functions
    
    fileprivate static func addOperation(withExecutionBlock block:(() -> Void), completionBlock:(() -> Void)?=nil) {
        
        let operation = BlockOperation { block() }
        operation.completionBlock = completionBlock
        
        if let latestOperation = self.queue.lastOperation() {
            operation.addDependency(latestOperation)
        }

        self.queue.addOperation(operation)
    
    }

    // MARK: - Private Properties
    
    private static let queue = Queue()
    private static let localDataCoordinator = LocalDataCoordinator()
    
    
    // MARK: - Private Classes
    
    private class Queue {
        
        
        // MARK: - Initializer
        
        init() {
            
            self.operationQueue.maxConcurrentOperationCount = 1
            self.operationQueue.qualityOfService = .userInteractive
            
        }
        
        
        // MARK: - Private Properties
        
        private let operationQueue = OperationQueue()
        
        
        // MARK: - Public Functions
        
        func addOperation(_ operation:Operation) {
            self.operationQueue.addOperation(operation)
        }
        
        func lastOperation() -> Operation? {
            return self.operationQueue.operations.last
        }
        
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
    
    func retrieveRecord(matching identifier:RecordIdentifier, retrievalCompleted:((Record?) -> Void)) {
        
        var record: Record? = nil
        
        let execution = {
            
            if let cachedRecord = self.retrievedRecordsCache[identifier] {
                
                record = cachedRecord
                
            } else {
                
                record = Mist.localRecordStorage.record(matching: identifier)
                self.retrievedRecordsCache[identifier] = record
                
            }
            
        }
        
        let completion = { retrievalCompleted(record) }
        
        Mist.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching filter:((Record) throws -> Bool), retrievalCompleted:(([Record], Error?) -> Void)) {
        
        var records: [Record] = []
        var error: Error?
        
        let execution = {
            
            do {
                
                let cachedRecords = try self.retrievedRecordsCache.values.filter(filter)
                if cachedRecords.count > 0 {
                    
                    records = cachedRecords
                    
                } else {
                    
                    try records = Mist.localRecordStorage.records(matching: filter)
                    
                    for record in records {
                        self.retrievedRecordsCache[record.identifier] = record
                    }
                    
                }
                
            } catch let fetchError {
                
                error = fetchError
                
            }
            
        }
        
        let completion = { retrievalCompleted(records, error) }
        
        Mist.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(matching predicate:NSPredicate, retrievalCompleted:(([Record]) -> Void)) {
        
        var records: [Record] = []
        
        let execution = {
            
            let cachedRecords = self.retrievedRecordsCache.values.filter({ predicate.evaluate(with: $0) }) as [Record]
            if cachedRecords.count > 0 {
                
                records = cachedRecords
                
            } else {
                
                records = Mist.localRecordStorage.records(matching: predicate)
                
                for record in records {
                    self.retrievedRecordsCache[record.identifier] = record
                }
                
            }
            
        }
        
        let completion = { retrievalCompleted(records) }
        
        Mist.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
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
                    self.retrievedRecordsCache[record.identifier] = record
                    Mist.localRecordStorage.addRecord(record)
                    Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.insert(record)
                    
                case .removal:
                    self.retrievedRecordsCache.removeValue(forKey: record.identifier)
                    Mist.localRecordStorage.removeRecord(record)
                    Mist.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud.insert(record)
                    Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud.remove(record)
                    
                }
                
            }
            
        }
        
        Mist.addOperation(withExecutionBlock: execution)
        
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
    
}


