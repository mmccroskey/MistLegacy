//
//  LocalCachedRecordChangesStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalCachedRecordChangesStorage {
    
    
    // MARK: - Caching Record Modifications
    
    var modifiedRecordsAwaitingPushToCloud: [Record] { get set }
    
    
    // MARK: - Caching Record Deletions
    
    var deletedRecordsAwaitingPushToCloud: [Record] { get set }
    
}
