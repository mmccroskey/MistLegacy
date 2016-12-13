//
//  DataCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/5/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

internal class DataCoordinator {
    
    
    // MARK: - Internal Properties
    
    internal let localCacheCoordinator = LocalCacheCoordinator()
    internal var currentUserCache: UserCache {
        
        guard let currentUser = Mist.currentUser else {
            
            fatalError(
                "We should never be calling currentUserCache when currentUser is nil, " +
                    "because all calls to this function should occur after guards for the  " +
                "existence of currentUser."
            )
            
        }
        
        return self.localCacheCoordinator.userCache(associatedWith: currentUser.identifier)
        
    }
    
    
    // MARK: - Private Properties
    
    private var typeString: String {
        
        let mirror = Mirror(reflecting: self)
        let selfType = mirror.subjectType as! DataCoordinator.Type
        let typeString = String(describing: selfType)
        
        return typeString
        
    }
    
}
