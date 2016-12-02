//
//  PublicOwnedRecord.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/2/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class PublicOwnedRecord: OwnedRecord {
    
    init(owner:CloudKitUser) {
        super.init(databaseWhereStored: .public, owner: owner)
    }
    
    internal init(backingRemoteRecord:CKRecord?=nil, owner:CloudKitUser) {
        super.init(databaseWhereStored: .public, backingRemoteRecord: backingRemoteRecord, owner: owner)
    }

}
