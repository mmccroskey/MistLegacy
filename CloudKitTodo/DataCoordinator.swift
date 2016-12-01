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

class DataCoordinator {
    
    
    // MARK: - Singleton Instance
    
    static let shared = DataCoordinator()
    
    
    // MARK: - Initializer
    
    init() {
        
        let typeString = String(describing: DataCoordinator.type())
        guard typeString != "DataCoordinator" else {
            fatalError("DataCoordinator is an abstract class; it must not be directly instantiated.")
        }
        
        self.localStorageInterface = InMemoryLocalStorageInterface()
        
    }
    
    
    // MARK: - Public Properties
    
    var localStorageInterface: LocalStorageInterface
    
    
    // MARK: Fetching Locally-Cached Items
    
    func retrieveAllCachedRecords() -> Set<Record> {
        return Set(self.localStorageInterface.allRecords.values)
    }
    
    func retrieveCachedRecord(matching potentiallyStaleInstance:Record) -> Record? {
        return self.retrieveCachedRecord(matching: potentiallyStaleInstance.identifier)
    }
    
    func retrieveCachedRecord(matching identifier:RecordIdentifier) -> Record? {
        return self.localStorageInterface.allRecords[identifier]
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:Record) {
        self.localStorageInterface.allRecords[record.identifier] = record
        self.localStorageInterface.changedRecordsAwaitingPushToCloud.insert(record)
    }
    
    func addRecords(_ records:Set<Record>) {
        
        for record in records {
            self.addRecord(record)
        }
        
    }
    
    func removeRecord(_ record:Record) {
        self.localStorageInterface.allRecords.removeValue(forKey: record.identifier)
        self.localStorageInterface.deletedRecordsAwaitingPushToCloud.insert(record)
        self.localStorageInterface.changedRecordsAwaitingPushToCloud.remove(record)
    }
    
    func removeAllRecords() {
        
        let allRecordsSet = Set(self.localStorageInterface.allRecords.values)
        let currentDeletedRecordsSet = self.localStorageInterface.deletedRecordsAwaitingPushToCloud
        
        self.localStorageInterface.deletedRecordsAwaitingPushToCloud = currentDeletedRecordsSet.union(allRecordsSet)
        
        self.localStorageInterface.allRecords.removeAll()
        
    }
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performCloudRefreshOfPublicData(inZone zone:CKRecordZone, completion:RefreshCompletion) {}
    
    func performCloudRefreshOfAllPrivateData(_ completion:RefreshCompletion) {}
    
    func performCloudRefreshOfPrivateObjectSubtree(originatingWith rootObject:Record, completion:RefreshCompletion) {}
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    func pushLocalChanges(_ completion:RefreshCompletion) {
        
        let scopes: [CKDatabaseScope] = [.public, .shared, .private]
        
        let unpushedChanges = self.localStorageInterface.changedRecordsAwaitingPushToCloud
        let unpushedDeletions = self.localStorageInterface.deletedRecordsAwaitingPushToCloud
        
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
    
    
    // MARK: - Private Functions
    
    private static func type() -> DataCoordinator.Type {
        return self
    }
    
}
