//
//  UserCache.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class UserCache {
    
    
    // MARK: - Initializers
    
    init (userIdentifier:RecordIdentifier) {
        self.userIdentifier = userIdentifier
    }
    
    
    // MARK: - Properties
    
    let userIdentifier: RecordIdentifier
    
    let publicCache = PublicCache()
    let privateCache = NonPublicCache()
    let sharedCache = NonPublicCache()
    
}
