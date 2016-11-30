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
    
    func allRecords() -> Set<Record>
    func record(matching recordIdentifier:RecordIdentifier) -> Record?
    
    
    // MARK: - Adding Records
    
    func addRecord(_ record:Record)
    func addRecords(_ records:Set<Record>)
    
    
    // MARK: - Removing Records
    
    func removeRecord(_ record:Record)
    func removeRecord(matching recordIdentifier:RecordIdentifier)
    func removeAllRecords()
    
    
    // MARK: - Storage for Changes Awaiting Push To Cloud
    
    var changedRecordsAwaitingPushToCloud: Set<Record> { get set }
    var deletedRecordsAwaitingPushToCloud: Set<Record> { get set }
    
    
}
