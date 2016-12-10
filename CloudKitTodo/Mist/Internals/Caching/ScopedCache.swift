//
//  ScopedCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class ScopedCache {
    
    
    // MARK: - Properties
    
    var cachedRecords: [RecordIdentifier : Record] = [:]
    var recordsWithUnpushedChanges: [RecordIdentifier : Record] = [:]
    var recordsWithUnpushedDeletions: [RecordIdentifier : Record] = [:]
    
}
