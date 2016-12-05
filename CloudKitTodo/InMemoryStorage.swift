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
    
    private enum StorageType {
        case stored
        case modified
        case deleted
    }
    
    private var publicStoredRecords: [RecordIdentifier : Record] = [:]
    private var userStoredRecords: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    
    private var userModifiedRecords: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    private var userDeletedRecords: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    
    private var metadata: [String:Any?] = [:]
    
    
    // MARK: - Private Functions
    
    private func scopedStorageForUser(identifiedBy userRecordIdentifier:RecordIdentifier, ofType type:StorageType, withScope scope:StorageScope) -> [RecordIdentifier : Record] {
        
        guard scope != .public else {
            fatalError("Public records are not associated with a User before being added to the local record store.")
        }
        
        let potentialExistingStorageForUser: [StorageScope : [RecordIdentifier : Record]]?
        switch type {
        case .stored:
            potentialExistingStorageForUser = self.userStoredRecords[userRecordIdentifier]
        case .modified:
            potentialExistingStorageForUser = self.userModifiedRecords[userRecordIdentifier]
        case .deleted:
            potentialExistingStorageForUser = self.userDeletedRecords[userRecordIdentifier]
        }
        
        var storageForUser: [StorageScope : [RecordIdentifier : Record]]
        if let existingStorageForUser = potentialExistingStorageForUser {
            storageForUser = existingStorageForUser
        } else {
            storageForUser = [:]
        }
        
        let potentialScopedStorageForUser: [RecordIdentifier : Record]? = storageForUser[scope]
        
        var scopedStorageForUser: [RecordIdentifier : Record]
        if let existingScopedStorageForUser = potentialScopedStorageForUser {
            scopedStorageForUser = existingScopedStorageForUser
        } else {
            scopedStorageForUser = [:]
        }
        
        storageForUser[scope] = scopedStorageForUser
        
        switch type {
        case .stored:
            self.userStoredRecords[userRecordIdentifier] = storageForUser
        case .modified:
            self.userModifiedRecords[userRecordIdentifier] = storageForUser
        case .deleted:
            self.userDeletedRecords[userRecordIdentifier] = storageForUser
        }
        
        return scopedStorageForUser
        
    }
    
    
    // MARK: - LocalCachedRecordChangesStorage Protocol Properties
    
    
    var publicModifiedRecordsAwaitingPushToCloud: Set<Record> = []
    var publicDeletedRecordsAwaitingPushToCloud: Set<Record> = []
    
    func userModifiedRecordsAwaitingPushToCloud(identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Set<Record> {
        
        let records = Set(self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .modified, withScope: scope).values)
        return records
        
    }
    
    func userDeletedRecordsAwaitingPushToCloud(identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Set<Record> {
        
        let records = Set(self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .deleted, withScope: scope).values)
        return records
        
    }
    
    func addUserModifiedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope) {
        
        var currentRecords = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .modified, withScope: scope)
        currentRecords[record.identifier] = record
        self.userModifiedRecords[userRecordIdentifier]![scope]! = currentRecords
        
    }
    
    func addUserDeletedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope) {
        
        var currentRecords = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .deleted, withScope: scope)
        currentRecords[record.identifier] = record
        self.userDeletedRecords[userRecordIdentifier]![scope]! = currentRecords
        
    }
    
    func removeUserModifiedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        
        var currentRecords = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .modified, withScope: scope)
        currentRecords.removeValue(forKey: record.identifier)
        self.userModifiedRecords[userRecordIdentifier]![scope]! = currentRecords
        
    }
    
    func removeUserDeletedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        
        var currentRecords = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .deleted, withScope: scope)
        currentRecords.removeValue(forKey: record.identifier)
        self.userDeletedRecords[userRecordIdentifier]![scope]! = currentRecords
        
    }
    
    
    
    // MARK: - LocalRecordStorage Protocol Functions
    
    
    
    // MARK: Adding & Modifying Records
    
    func addPublicRecord(_ record:Record) {
        self.publicStoredRecords[record.identifier] = record
    }
    
    func addUserRecord(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope) {
        
        var storageForUser = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .stored, withScope: scope)
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
    
    func removeUserRecord(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        self.removeUserRecord(matching: record.identifier, identifiedBy: userRecordIdentifier, fromScope: scope)
    }
    
    func removeUserRecord(matching identifier:RecordIdentifier, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope) {
        
        var storageForUser = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .stored, withScope: scope)
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
    
    func userRecord(matching identifier:RecordIdentifier, identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Record? {
        
        let storageForUser = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .stored, withScope: scope)
        return storageForUser[identifier]
        
    }
    
    func userRecords(matching filter:((Record) throws -> Bool), identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) rethrows -> [Record]{
        
        let storageForUser = self.scopedStorageForUser(identifiedBy: userRecordIdentifier, ofType: .stored, withScope: scope)
        return try storageForUser.values.filter(filter)
        
    }
    
    func userRecords(matching predicate:NSPredicate, identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> [Record] {
        return self.userRecords(matching: { predicate.evaluate(with: $0) }, identifiedBy: userRecordIdentifier, inScope: scope)
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
