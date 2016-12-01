//
//  InMemoryLocalStorageInterface.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class InMemoryLocalStorageInterface: LocalStorageInterface {
    
    var allRecords: [RecordIdentifier : Record] = [:]
    
    var changedRecordsAwaitingPushToCloud: Set<Record> = []
    var deletedRecordsAwaitingPushToCloud: Set<Record> = []
    
}
