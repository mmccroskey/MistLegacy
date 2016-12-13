//
//  NonPublicCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/10/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

class NonPublicCache: ScopedCache {
    
    var scopeChangeToken: CKServerChangeToken? = nil
    var recordZoneChangeTokens: [RecordZoneIdentifier : CKServerChangeToken?] = [:]
    
}
