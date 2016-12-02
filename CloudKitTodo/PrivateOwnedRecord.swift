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
    
    
    // MARK: - Initializers
    
    init(owner:CloudKitUser) {
        
        self.zone = PrivateOwnedRecord.zone(with: owner)
        super.init(databaseWhereStored: .private, owner: owner)
        
    }
    
    internal override init(databaseWhereStored:CKDatabaseScope, backingRemoteRecord:CKRecord?=nil, owner:CloudKitUser) {
        
        guard databaseWhereStored != .public else {
            fatalError("Private Records must be stored in the private or shared databases, not the public database.")
        }
        
        self.zone = PrivateOwnedRecord.zone(with: owner)
        
        super.init(databaseWhereStored: databaseWhereStored, backingRemoteRecord: backingRemoteRecord, owner: owner)
        
    }
    
    
    // MARK: - Public Properties
    
    internal let zone: CKRecordZone
    
    
    // MARK: - Private Static Functions
    
    private static func zone(with owner:CloudKitUser) -> CKRecordZone {
        
        let zoneName = UUID().uuidString
        let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: owner.identifier)
        
        return CKRecordZone(zoneID: zoneID)
        
    }
    
}
