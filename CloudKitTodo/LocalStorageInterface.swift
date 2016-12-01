//
//  LocalStorageInterface.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalStorageInterface {
    
    var allRecords: [RecordIdentifier : Record] { get set }
    
    var changedRecordsAwaitingPushToCloud: Set<Record> { get set }
    var deletedRecordsAwaitingPushToCloud: Set<Record> { get set }
    
}
