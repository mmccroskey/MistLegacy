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
typealias RecordIdentifier = String
typealias RelationshipDeleteBehavior = CKReferenceAction
typealias FilterClosure = ((Record) throws -> Bool)


struct Configuration {
    
    var `public`: Scoped
    var `private`: Scoped
    var shared: Scoped
    
    struct Scoped {
        
        var pullRecordsMatchingDescriptors: [RecordDescriptor]?
        
    }
    
}

struct RecordDescriptor {
    
    let type: Record.Type
    let descriptor: NSPredicate
    
}


class Mist {
    
    
    // MARK: - Configuration Properties
    
    static var config: Configuration = Configuration(
        public: Configuration.Scoped(pullRecordsMatchingDescriptors: nil),
        private: Configuration.Scoped(pullRecordsMatchingDescriptors: nil),
        shared: Configuration.Scoped(pullRecordsMatchingDescriptors: nil)
    )
    
    static var localRecordStorage: LocalRecordStorage = InMemoryStorage()
    static var localMetadataStorage: LocalMetadataStorage = InMemoryStorage()
    static var localCachedRecordChangesStorage: LocalCachedRecordChangesStorage = InMemoryStorage()
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, from:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, Record?) -> Void)) {
        self.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWithScope: from, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(recordsOfType type:Record.Type, where filter:FilterClosure, within:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(withType:type, matching: filter, inStorageWithScope: within, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(recordsOfType type:Record.Type, where predicate:NSPredicate, within:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(withType:type, matching: predicate, inStorageWithScope: within, fetchDepth:fetchDepth, retrievalCompleted: finished)
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.addRecord(record, toStorageWith: to, finished: finished)
    }
    
    static func add(_ records:Set<Record>, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.addRecords(records, toStorageWith: to, finished: finished)
    }
    
    static func remove(_ record:Record, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.removeRecord(record, fromStorageWith: from, finished: finished)
    }
    
    static func remove(_ records:Set<Record>, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.removeRecords(records, fromStorageWith: from, finished: finished)
    }
    
    
    // MARK: - Syncing Items
    
    static func sync(_ qOS:QualityOfService?=QualityOfService.default, finished:((SyncSummary) -> Void)?=nil) {
        self.synchronizationCoordinator.sync(qOS, finished: finished)
    }
    
    
    // MARK: - Internal Properties
    
    internal static let localRecordsQueue = Queue()
    internal static let localMetadataQueue = Queue()
    internal static let localCachedRecordChangesQueue = Queue()
    
    internal static let localDataCoordinator = LocalDataCoordinator()
    internal static let remoteDataCoordinator = RemoteDataCoordinator()
    internal static let synchronizationCoordinator = SynchronizationCoordinator()
    
}

