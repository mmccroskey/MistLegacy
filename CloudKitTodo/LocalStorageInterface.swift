//
//  LocalStorageInterface.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalStorageInterface {
    
    
    // MARK: - Retrieving Records
    
    func allRecords() -> Set<LocalRecord>
    func record(matching recordIdentifier:RecordIdentifier) -> LocalRecord?
    
    
    // MARK: - Adding Records
    
    func addRecord(_ record:LocalRecord)
    func addRecords(_ records:Set<LocalRecord>)
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:LocalRecord)
    func removeRecord(matching recordIdentifier:RecordIdentifier)
    func removeAllRecords()
    
    
}
