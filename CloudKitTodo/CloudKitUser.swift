//
//  CloudKitUser.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitUser : Record {
    
    init(backingRemoteRecord:CKRecord?=nil) {
        
        let zoneName = UUID().uuidString as RecordIdentifier
        self.ownedRecordsZone = CKRecordZone(zoneName: zoneName)
        
        super.init(databaseWhereStored: .public, backingRemoteRecord:backingRemoteRecord)
        
    }
    
    let ownedRecordsZone: CKRecordZone
    
}
