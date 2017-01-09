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
    let privateCache = NonPublicCache(scope: .private)
    let sharedCache = NonPublicCache(scope: .shared)
    
    
    // MARK: - Functions
    
    func scopedCache(withScope scope:StorageScope) -> ScopedCache {
        
        switch scope {
            
        case .public:
            return self.publicCache
            
        case .private:
            return self.privateCache
            
        case .shared:
            return self.sharedCache
            
        }
        
    }
    
}
