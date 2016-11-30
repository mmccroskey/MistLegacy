//
//  NestedRecord.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class NestedRecord: LocalRecord {
    
    
    // MARK: - Initializers
    
    init(cloudDatabase:CKDatabase, parent:LocalRecord) {
        
        self.parent = parent
        
        super.init(cloudDatabase: cloudDatabase)
        
        self.backingRemoteRecord.setParent(parent.backingRemoteRecord)
        
    }
    
    
    // MARK: - Public Properties
    
    let parent: LocalRecord
    
}
