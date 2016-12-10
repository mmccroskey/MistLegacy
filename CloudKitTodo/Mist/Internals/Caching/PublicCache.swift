//
//  PublicCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class PublicCache: ScopedCache {
    
    
    // MARK: - Public Properties
    
    var recordDescriptorsForLocallyCreatedRecords: [RecordDescriptor] = []
    var locallyCreatedRecordsByRecordType: [String : Set<Record>] = [:]
    
}
