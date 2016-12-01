//
//  Record.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 11/30/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit

typealias RecordIdentifier = String
typealias RecordAccessibility = CKDatabaseScope

class Record: Hashable {
    
    
    // MARK: - Initializers
    
    init(accessibility:RecordAccessibility, recordZone:CKRecordZone) {
        
        let typeString = String(describing: Record.type())
        guard typeString != "Record" else {
            fatalError("Record is an abstract class; it must not be directly instantiated.")
        }
        
        self.accessibility = accessibility
        self.recordZone = recordZone
        
        self.identifier = UUID().uuidString as RecordIdentifier
        
        let recordID = CKRecordID(recordName: self.identifier)
        self.backingRemoteRecord = CKRecord(recordType: typeString, recordID: recordID)
        
    }
    
    
    // MARK: - Public Properties
    
    let accessibility: RecordAccessibility
    let recordZone: CKRecordZone
    
    var typeString: String {
        
        let mirror = Mirror(reflecting: self)
        let selfType = mirror.subjectType as! Record.Type
        let selfTypeString = String(describing: selfType)
        
        return selfTypeString
        
    }
    
    let identifier: RecordIdentifier
    
    
    // MARK: - Public Functions
    
    func value(forKey key:String) -> Any? {
        
        guard let value = self.backingRemoteRecord.value(forKey: key) else {
            return nil
        }
        
        if let reference = value as? CKReference {
            
            guard let value = DataCoordinator.shared.retrieveCachedRecord(matching: reference.recordID.recordName) else {
                
                fatalError(
                    "ERROR: When attempting to get the value for the key \(key) in the backingRemoteRecord, " +
                    "we found a CKReference, but we have no object for its corresponding identifier " +
                    "in our local store. Here's the Record we were searching: \(self)"
                )
                
            }
            
            return value
            
        } else {
            
            return value
            
        }
        
    }
    
    func setValue(_ value:Any?, forKey key:String) {
        
        guard !(value is Record) else {
            fatalError("To set another RelatedRecord as the value for a key on Record, please use the setRelatedRecord:forKey: function.")
        }
        
        guard value is CKRecordValue else {
            fatalError("ERROR: Every value of Record must conform to CKRecordValue. The value you've provided does not; here it is: \(value)")
        }
        
        self.backingRemoteRecord.setValue(value, forKey: key)
        
    }
    
    func setRelatedRecord(_ relatedRecord:Record, forKey key:String, withReferenceAction action:CKReferenceAction) {
        
        // First make sure the CKReference exists and is properly configured
        
        func configureNewReference() {
            let newReference = CKReference(record: relatedRecord.backingRemoteRecord, action: action)
            self.backingRemoteRecord.setValue(newReference, forKey: key)
        }
        
        if let extantObject = self.backingRemoteRecord.value(forKey: key) {
            
            // Ensure we aren't overwriting a basic property
            guard let extantReference = extantObject as? CKReference else {
                
                fatalError(
                    "ERROR: You're attempting to store a Record (aka a relation) " +
                    "under a key where a non-relation is currently stored. This is " +
                    "not allowed. Here are the relevant details:\n" +
                    "KEY: \(key)\n" +
                    "CURRENT VALUE: \(extantObject)\n" +
                    "PROPOSED NEW VALUE: \(value)\n" +
                    "RECORD BEING MODIFIED: \(self)\n"
                )
                
            }
            
            // Ensure the stored reference is pointing to the right object
            if extantReference.recordID.recordName != relatedRecord.backingRemoteRecord.recordID.recordName {
                configureNewReference()
            }
            
        } else {
            configureNewReference()
        }
        
        // Then make sure the relatedRecord is saved in the DataCoordinator
        DataCoordinator.shared.addRecord(relatedRecord)
        
    }
    
    
    // MARK: - Private Properties
    
    internal let backingRemoteRecord: CKRecord
    
    
    // MARK: - Private Functions
    
    private static func type() -> Record.Type {
        return self
    }
    
    
    // MARK: - Protocol Conformance
    
    var hashValue: Int {
        return self.backingRemoteRecord.hashValue
    }
    
    static func ==(left:Record, right:Record) -> Bool {
        return left.backingRemoteRecord == right.backingRemoteRecord
    }
    
}
