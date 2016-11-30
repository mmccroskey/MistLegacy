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
        
    }
    
    
    // MARK: - Public Properties
    
//    var todos: StructuredLocalRecordStorage {
//        
//        get {
//            
//            let allTodos = self.records.values.filter { return $0.typeString == "Todo" }
//            
//            
//            
//        }
//        
//    }
    
    
    // MARK: Fetching Items
    
    func retrieveCachedRecord(matching potentiallyStaleInstance:LocalRecord) -> LocalRecord? {
        return self.retrieveCachedRecord(matching: potentiallyStaleInstance.identifier)
    }
    
    func retrieveCachedRecord(matching identifier:RecordIdentifier) -> LocalRecord? {
        
        if let record = self.records.values.filter({ $0.identifier == identifier }).first {
            return record
        }
        
        return nil
        
    }
    
    
    // MARK: - Setting Items
    
    func addRecord(_ record:LocalRecord) {
        
        let identifier = record.identifier
        
        self.records[identifier] = record
        self.recordsWithChangesNotYetSavedToCloud[identifier] = record
        
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
