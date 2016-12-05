//
//  Queue.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/5/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

internal class Queue {
    
    
    // MARK: - Initializer
    
    init() {
        
        self.operationQueue.maxConcurrentOperationCount = 1
        self.operationQueue.qualityOfService = .userInteractive
        
    }
    
    
    // MARK: - Private Properties
    
    private let operationQueue = OperationQueue()
    
    
    // MARK: - Public Functions
    
    func addOperation(_ block:(() -> Void)) {
        self.addOperation(withExecutionBlock: block)
    }
    
    func addOperation(withExecutionBlock block:(() -> Void), completionBlock:(() -> Void)?=nil) {
        
        let operation = BlockOperation { block() }
        operation.completionBlock = completionBlock
        
        if let latestOperation = self.operationQueue.operations.last {
            operation.addDependency(latestOperation)
        }
        
        self.operationQueue.addOperation(operation)
        
    }
    
}
