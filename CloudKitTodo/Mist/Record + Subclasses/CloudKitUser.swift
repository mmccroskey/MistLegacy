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
    
    init() { super.init(className: "CloudKitUser") }
    override init(backingRemoteRecord: CKRecord) { super.init(backingRemoteRecord: backingRemoteRecord) }
    
}
