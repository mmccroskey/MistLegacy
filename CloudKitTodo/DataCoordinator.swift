//
//  DataCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

typealias LocalRecordStorage = [RecordIdentifier : LocalRecord]
typealias StructuredLocalRecordStorage = [String : LocalRecordStorage]
typealias RefreshCompletion = ((Bool, Error?) -> Void)

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
    
    func retrieveAllCachedRecords() -> Set<LocalRecord> {
        return self.localStorageInterface.allRecords()
    }
    
    func retrieveCachedRecord(matching potentiallyStaleInstance:LocalRecord) -> LocalRecord? {
        return self.retrieveCachedRecord(matching: potentiallyStaleInstance.identifier)
    }
    
    func retrieveCachedRecord(matching identifier:RecordIdentifier) -> LocalRecord? {
        return self.localStorageInterface.record(matching: identifier)
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:LocalRecord) {
        self.localStorageInterface.addRecord(record)
    }
    
    func addRecords(_ records:Set<LocalRecord>) {
        self.localStorageInterface.addRecords(records)
    }
    
    func removeRecord(_ record:LocalRecord) {
        self.removeRecord(matching: record.identifier)
    }
    
    func removeRecord(matching recordIdentifier:RecordIdentifier) {
        self.localStorageInterface.removeRecord(matching: recordIdentifier)
    }
    
    func removeAllRecords() {
        self.localStorageInterface.removeAllRecords()
    }
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performCloudRefreshOfPublicData(inZone zone:CKRecordZone, completion:RefreshCompletion) {}
    
    func performCloudRefreshOfPrivateData(_ completion:RefreshCompletion) {}
    
    func performCloudRefreshOfPrivateObjectSubtree(originatingWith rootObject:LocalRecord, completion:RefreshCompletion) {}
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    
    
    // MARK: - Private Properties
    
    private var records: LocalRecordStorage = [:]
    private var recordsWithChangesNotYetSavedToCloud: LocalRecordStorage = [:]
    
    
    // MARK: - Private Functions
    
    private static func type() -> DataCoordinator.Type {
        return self
    }
    
}
