//
//  LocalMetadataStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalMetadataStorage {
    
    
    // MARK: - Getting Values
    
    func value(forKey key:String) -> Any?
    
    
    // MARK: - Setting Values
    
    func setValue(_ value:Any?, forKey key:String)
    
}
