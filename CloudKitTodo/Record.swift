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

internal struct RelatedRecordData {
    
    let identifier: RecordIdentifier
    let action: CKReferenceAction
    
}

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
        
        for key in self.backingRemoteRecord.allKeys() {
            
            if let reference = self.backingRemoteRecord.object(forKey: key) as? CKReference {
                
                let relatedRecordData = RelatedRecordData(identifier: reference.recordID.recordName, action: reference.referenceAction)
                self.relatedRecordDataSetKeyPairs[key] = relatedRecordData
                
            }
            
        }
        
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
    
    
    // MARK: - Protected Properties
    
    internal let backingRemoteRecord: CKRecord
    internal var relatedRecordsCache: [String : Record] = [:]
    internal var relatedRecordDataSetKeyPairs: [String : RelatedRecordData] = [:]
    
    
    // MARK: - Interacting with Record Properties
    
    func object(forKey key:String) -> CKRecordValue? {
        
        if let object = self.backingRemoteRecord.object(forKey: key) {
            
            guard !(object is CKReference) else {
                
                fatalError(
                    "Do not fetch relationships using object(forKey:) -- use " +
                    "relatedRecord(forKey:) instead. Here are the object and key in question:\n" +
                    "OBJECT: \(self)\n" +
                    "KEY: \(key)"
                )
                
            }
            
            return object
            
        }

        return nil
        
    }
    
    func setObject(_ object:CKRecordValue?, forKey key:String) {
        
        guard !(object is CKReference) else {
            
            fatalError(
                "Do not set relationships using setObject(forKey:) -- use " +
                 "setRelatedRecord(forKey:withReferenceAction:) instead. Here are the object and key in question:\n" +
                 "OBJECT: \(self)\n" +
                 "KEY: \(key)"
            )
            
        }
        
        self.backingRemoteRecord.setObject(object, forKey: key)
        
    }
    
    
    // MARK: - Interacting with Record Relationships
    
    func relatedRecord(forKey key:String) -> Record? {
        return self.relatedRecordsCache[key]
    }
    
    func setRelatedRecord(_ relatedRecord:Record?, forKey key:String, withReferenceAction action:CKReferenceAction) {
        
        func configureReference(using record:Record?) {
            
            if let record = record {
                
                let newReference = CKReference(record: record.backingRemoteRecord, action: action)
                self.backingRemoteRecord.setObject(newReference, forKey: key)
                
            } else {
                
                self.backingRemoteRecord.setObject(nil, forKey: key)
                
            }
            
        }
        
        if let relatedRecord = relatedRecord {
            
            // First make sure the CKReference exists and is properly configured
            if let extantObject = self.backingRemoteRecord.object(forKey: key) {
                
                // Ensure we aren't overwriting a basic property
                guard let extantReference = extantObject as? CKReference else {
                    
                    fatalError(
                        "ERROR: You're attempting to store a Record (aka a relation) " +
                        "under a key where a non-relation is currently stored. This is " +
                        "not allowed. Here are the relevant details:\n" +
                        "KEY: \(key)\n" +
                        "CURRENT VALUE: \(extantObject)\n" +
                        "PROPOSED NEW OBJECT: \(object)\n" +
                        "RECORD BEING MODIFIED: \(self)\n"
                    )
                    
                }
                
                // Ensure the stored reference is pointing to the right object
                if extantReference.recordID.recordName != relatedRecord.backingRemoteRecord.recordID.recordName {
                    configureReference(using: relatedRecord)
                }
                
            } else {
                configureReference(using: relatedRecord)
            }
            
            // Add it to our internal cache of related Records
            self.relatedRecordsCache[key] = relatedRecord
            
            // Ensure the Record exists in Mist
            Mist.add(relatedRecord)
            
            
        } else {
            
            // Remove the CKReference if it exists
            configureReference(using: nil)
            
            // Remove it from our internal cache of related Records
            self.relatedRecordsCache.removeValue(forKey: key)
            
        }
        
    }
    
    
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
