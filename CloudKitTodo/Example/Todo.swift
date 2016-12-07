//
//  Todo.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

class Todo: Record {
    
    init() { super.init(className: "Todo") }
    
    var title: String? {
        
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey: "title") }
        
    }
    
    var dueDate: Date? {
        
        get { return self.propertyValue(forKey: "dueDate") as? Date }
        set { self.setPropertyValue(newValue as? RecordValue, forKey: "dueDate") }
        
    }
    
}
