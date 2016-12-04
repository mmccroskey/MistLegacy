//
//  InMemoryLocalRecordStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class InMemoryStorage: LocalRecordStorage, LocalMetadataStorage, LocalCachedRecordChangesStorage {
    
    
    // MARK: - Private Properties
    
    private var publicStoredRecords: [RecordIdentifier : Record] = [:]
    private var userStoredRecords: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    
    private var metadata: [String:Any?] = [:]
    
    
    // MARK: - Private Functions
    
    private func scopedStorageForUser(associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, withScope scope:StorageScope) -> [RecordIdentifier : Record] {
        
        guard scope != .public else {
            fatalError("Public records are not associated with a User before being added to the local record store.")
        }
        
        let potentialExistingStorageForUser: [StorageScope : [RecordIdentifier : Record]]? = self.userStoredRecords[userRecordIdentifier]
        
        var storageForUser: [StorageScope : [RecordIdentifier : Record]]
        if let existingStorageForUser = potentialExistingStorageForUser {
            storageForUser = existingStorageForUser
        } else {
            storageForUser = [:]
        }
        self.userStoredRecords[userRecordIdentifier] = storageForUser
        
        let potentialScopedStorageForUser: [RecordIdentifier : Record]? = self.userStoredRecords[userRecordIdentifier]?[scope]
        
        var scopedStorageForUser: [RecordIdentifier : Record]
        if let existingScopedStorageForUser = potentialScopedStorageForUser {
            scopedStorageForUser = existingScopedStorageForUser
        } else {
            scopedStorageForUser = [:]
        }
        
        return scopedStorageForUser
        
    }
    
    
    // MARK: - LocalCachedRecordChangesStorage Protocol Properties
    
    
    var modifiedRecordsAwaitingPushToCloud: Set<Record> = []
    var deletedRecordsAwaitingPushToCloud: Set<Record> = []
    
    
    // MARK: - LocalRecordStorage Protocol Functions
    
    
    
    // MARK: Adding & Modifying Records
    
    func addPublicRecord(_ record:Record) {
        self.publicStoredRecords[record.identifier] = record
    }
    
    func addUserRecord(_ record:Record, associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope) {
        
        var storageForUser = self.scopedStorageForUser(associatedWithUserIdentifier: userRecordIdentifier, withScope: scope)
        storageForUser[record.identifier] = record
        self.userStoredRecords[userRecordIdentifier]![scope] = storageForUser
        
    }
    
    
    // MARK: Removing Records
    
    func removePublicRecord(_ record:Record) {
        self.removePublicRecord(matching: record.identifier)
    }
    
    func removePublicRecord(matching identifier:RecordIdentifier) {
        self.publicStoredRecords.removeValue(forKey: identifier)
    }
    
    func removeUserRecord(_ record:Record, associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        self.removeUserRecord(matching: record.identifier, associatedWithUserIdentifier: userRecordIdentifier, fromScope: scope)
    }
    
    func removeUserRecord(matching identifier:RecordIdentifier, associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        
        var storageForUser = self.scopedStorageForUser(associatedWithUserIdentifier: userRecordIdentifier, withScope: scope)
        storageForUser.removeValue(forKey: identifier)
        self.userStoredRecords[userRecordIdentifier]![scope] = storageForUser
        
    }
    
    
    // MARK: Finding Records
    
    func publicRecord(matching identifier:RecordIdentifier) -> Record? {
        return self.publicStoredRecords[identifier]
    }
    
    func publicRecords(matching filter:((Record) throws -> Bool)) rethrows -> [Record] {
        return try self.publicStoredRecords.values.filter(filter)
    }
    
    func publicRecords(matching predicate:NSPredicate) -> [Record] {
        return self.publicRecords(matching: { predicate.evaluate(with: $0) })
    }
    
    func userRecord(matching identifier:RecordIdentifier, associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Record? {
        
        let storageForUser = self.scopedStorageForUser(associatedWithUserIdentifier: userRecordIdentifier, withScope: scope)
        return storageForUser[identifier]
        
    }
    
    func userRecords(matching filter:((Record) throws -> Bool), associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) rethrows -> [Record]{
        
        let storageForUser = self.scopedStorageForUser(associatedWithUserIdentifier: userRecordIdentifier, withScope: scope)
        return try storageForUser.values.filter(filter)
        
    }
    
    func userRecords(matching predicate:NSPredicate, associatedWithUserIdentifier userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> [Record] {
        return self.userRecords(matching: { predicate.evaluate(with: $0) }, associatedWithUserIdentifier: userRecordIdentifier, inScope: scope)
    }
    
    
    // MARK: - LocalMetadataStorage Protocol Functions
    
    
    // MARK: - Getting Values
    
    func value(forKey key:String) -> Any? {
        return self.metadata[key]
    }
    
    
    // MARK: - Setting Values
    
    func setValue(_ value:Any?, forKey key:String) {
        self.metadata[key] = value
    }
    
}
