//
//  OwnedRecord.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/2/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class OwnedRecord: Record {
    
    
    // MARK: - Initializer
    
    internal init(databaseWhereStored:CKDatabaseScope, backingRemoteRecord:CKRecord?=nil, owner:CloudKitUser) {
        
        let typeString = String(describing: Record.type())
        guard ((typeString != "Record") && (typeString != "OwnedRecord")) else {
            fatalError("\(typeString) is an abstract class; it must not be directly instantiated.")
        }
        
        self.owner = owner
        super.init(databaseWhereStored: databaseWhereStored, backingRemoteRecord: backingRemoteRecord)
        
    }
    
    
    // MARK: - Public Properties
    
    let owner: CloudKitUser
    
}
