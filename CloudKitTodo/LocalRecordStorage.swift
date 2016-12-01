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
    
    func addRecord(_ record:Record)
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:Record) -> Bool
    func removeRecord(matching identifier:RecordIdentifier) -> Bool
    
    
    // MARK: - Finding Records
    
    func record(matching identifier:RecordIdentifier) -> Record?
    func records(matching filter:((Record) throws -> Bool)) rethrows -> [Record]
    func records(matching predicate:NSPredicate) -> [Record]
    
}
