//
//  LocalCacheCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/9/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class LocalCacheCoordinator {
    
    
    // MARK: - Public Functions
    
    func userCache(associatedWith userIdentifier:RecordIdentifier) -> UserCache {
        
        if let userCache = self.userCaches[userIdentifier] {
            
            return userCache
            
        } else {
            
            let userCache = UserCache(userIdentifier: userIdentifier)
            self.userCaches[userIdentifier] = userCache
            
            return userCache
            
        }
        
    }
    
    
    // MARK: - Private Properties
    
    private var userCaches: [RecordIdentifier : UserCache] = [:]
    
}
