//
//  PrivateOwnedRecord.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/2/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class PrivateOwnedRecord: OwnedRecord {
    
    
    // MARK: - Initializer
    
    override init(databaseWhereStored:CKDatabaseScope, backingRemoteRecord:CKRecord?=nil, owner:CloudKitUser) {
        
        guard databaseWhereStored != .public else {
            fatalError("Private Records must be stored in the private or shared databases, not the public database.")
        }
        
        let zoneName = UUID().uuidString
        let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: owner.identifier)
        self.zone = CKRecordZone(zoneID: zoneID)
        
        super.init(databaseWhereStored: databaseWhereStored, backingRemoteRecord: backingRemoteRecord, owner: owner)
        
    }
    
    // MARK: - Public Properties
    
    internal let zone: CKRecordZone
    
}
