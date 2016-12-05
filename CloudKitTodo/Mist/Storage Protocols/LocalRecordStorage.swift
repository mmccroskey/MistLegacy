//
//  LocalRecordStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalRecordStorage {
    
    
    // MARK: - Adding & Modifying Records
    
    func addPublicRecord(_ record:Record)
    func addUserRecord(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope)
    
    
    // MARK: - Removing Records
    
    func removePublicRecord(_ record:Record)
    func removePublicRecord(matching identifier:RecordIdentifier)
    
    func removeUserRecord(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope)
    func removeUserRecord(matching identifier:RecordIdentifier, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope)
    
    
    // MARK: - Finding Records
    
    func publicRecord(matching identifier:RecordIdentifier) -> Record?
    func publicRecords(matching filter:((Record) throws -> Bool)) rethrows -> [Record]
    func publicRecords(matching predicate:NSPredicate) -> [Record]
    
    func userRecord(matching identifier:RecordIdentifier, identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Record?
    func userRecords(matching filter:((Record) throws -> Bool), identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) rethrows -> [Record]
    func userRecords(matching predicate:NSPredicate, identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> [Record]
    
}
