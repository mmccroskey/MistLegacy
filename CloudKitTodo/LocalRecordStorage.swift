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
    
    func addRecord(_ record:Record, toStorageWith scope:StorageScope)
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:Record, fromStorageWith scope:StorageScope)
    func removeRecord(matching identifier:RecordIdentifier, fromStorageWith scope:StorageScope)
    
    
    // MARK: - Finding Records
    
    func record(matching identifier:RecordIdentifier, inStorageWith scope:StorageScope) -> Record?
    func records(matching filter:((Record) throws -> Bool), inStorageWith scope:StorageScope) rethrows -> [Record]
    func records(matching predicate:NSPredicate, inStorageWith scope:StorageScope) -> [Record]
    
}
