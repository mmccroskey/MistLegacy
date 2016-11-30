//
//  RootRecord.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class RootRecord: LocalRecord {
    
    
    // MARK: - Initializers
    
    init(owner:User) {
        
        let zoneName = UUID().uuidString as RecordIdentifier
        let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: owner.identifier)
        let recordZone = CKRecordZone(zoneID: recordZoneID)
        
        self.recordZone = recordZone
        
    }
    
    
    // MARK: - Public Properties
    
    let recordZone: CKRecordZone
    
}
