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

internal struct RelatedRecordData {
    
    let identifier: RecordIdentifier
    let action: CKReferenceAction
    
}

class Record: Hashable {
    
    
    // MARK: - Initializer
    
    internal init(backingRemoteRecord:CKRecord?=nil) {
        
        let typeString = String(describing: Record.type())
        guard typeString != "Record" else {
            fatalError("Record is an abstract class; it must not be directly instantiated.")
        }
        
        if let backingRemoteRecord = backingRemoteRecord {
            
            self.identifier = backingRemoteRecord.recordID.recordName
            
            self.backingRemoteRecord = backingRemoteRecord
            
        } else {
            
            self.identifier = UUID().uuidString as RecordIdentifier
            
            let recordID = CKRecordID(recordName: self.identifier)
            self.backingRemoteRecord = CKRecord(recordType: typeString, recordID: recordID)
            
        }
        
        for key in self.backingRemoteRecord.allKeys() {
            
            if let reference = self.backingRemoteRecord.object(forKey: key) as? CKReference {
                
                let relatedRecordData = RelatedRecordData(identifier: reference.recordID.recordName, action: reference.referenceAction)
                self.relatedRecordDataSetKeyPairs[key] = relatedRecordData
                
            }
            
        }
        
    }
    
    
    // MARK: - Public Properties
    
    var parent: Record? {
        
        willSet {
            
            if let parent = newValue {
                Record.ensureDatabasesAndRecordZonesMatch(between: parent, and: self)
            }
            
        }
        
    }
    
    var typeString: String {
        
        let mirror = Mirror(reflecting: self)
        let selfType = mirror.subjectType as! Record.Type
        let selfTypeString = String(describing: selfType)
        
        return selfTypeString
        
    }
    
    let identifier: RecordIdentifier
    
    
    // MARK: - Protected Properties
    
    internal var databaseWhereStored: CKDatabaseScope?
    internal var recordZone: CKRecordZone?
    
    internal let backingRemoteRecord: CKRecord
    
    internal var relatedRecordsCache: [String : Record] = [:]
    internal var relatedRecordDataSetKeyPairs: [String : RelatedRecordData] = [:]
    
    
    // MARK: - Interacting with Record Properties
    
    func property(forKey key:String) -> CKRecordValue? {
        
        if let property = self.backingRemoteRecord.object(forKey: key) {
            
            guard !(property is CKReference) else {
                
                fatalError(
                    "Do not fetch relationships using object(forKey:) -- use " +
                    "relatedRecord(forKey:) instead. Here are the object and key in question:\n" +
                    "OBJECT: \(self)\n" +
                    "KEY: \(key)"
                )
                
            }
            
            return property
            
        }

        return nil
        
    }
    
    func setProperty(_ property:CKRecordValue?, forKey key:String) {
        
        guard !(property is CKReference) else {
            
            fatalError(
                "Do not set relationships using setObject(forKey:) -- use " +
                 "setRelatedRecord(forKey:withReferenceAction:) instead. Here are the object and key in question:\n" +
                 "OBJECT: \(self)\n" +
                 "KEY: \(key)"
            )
            
        }
        
        self.backingRemoteRecord.setObject(property, forKey: key)
        
    }
    
    
    // MARK: - Interacting with Record Relationships
    
    func relatedRecord(forKey key:String) -> Record? {
        return self.relatedRecordsCache[key]
    }
    
    func setRelatedRecord(_ relatedRecord:Record?, forKey key:String, withReferenceAction action:CKReferenceAction) {
        
        func configureReference() {
            
            if let relatedRecord = relatedRecord {
                
                let newReference = CKReference(record: relatedRecord.backingRemoteRecord, action: action)
                self.backingRemoteRecord.setObject(newReference, forKey: key)
                
            } else {
                
                self.backingRemoteRecord.setObject(nil, forKey: key)
                
            }
            
        }
        
        if let relatedRecord = relatedRecord {
            
            if let extantObject = self.backingRemoteRecord.object(forKey: key) {
                
                guard let extantReference = extantObject as? CKReference else {
                    
                    fatalError(
                        "ERROR: You're attempting to store a Record (aka a relation) " +
                        "under a key where a non-relation is currently stored. This is " +
                        "not allowed. Here are the relevant details:\n" +
                        "KEY: \(key)\n" +
                        "CURRENT VALUE: \(extantObject)\n" +
                        "PROPOSED NEW OBJECT: \(relatedRecord)\n" +
                        "RECORD BEING MODIFIED: \(self)\n"
                    )
                    
                }
                
                if extantReference.recordID.recordName != relatedRecord.backingRemoteRecord.recordID.recordName {
                    configureReference()
                }
                
            } else {
                configureReference()
            }
            
            Record.ensureDatabasesAndRecordZonesMatch(between: self, and: relatedRecord)
            
            self.relatedRecordsCache[key] = relatedRecord
            
        } else {
            
            // Remove the CKReference if it exists
            configureReference()
            
            // Remove it from our internal cache of related Records
            self.relatedRecordsCache.removeValue(forKey: key)
            
        }
        
    }
    
    
    // MARK: - Internal Functions
    
    internal static func type() -> Record.Type {
        return self
    }
    
    internal static func ensureDatabasesAndRecordZonesMatch(between providingRecord:Record, and dependentRecord:Record) {
        
        func mismatchFatalError(with typeName:String) -> Never {
            
            fatalError(
                "ERROR: A dependent Record must be in the same \(typeName) as the Record on which it is dependent. " +
                "Here are the Records (and respective \(typeName)s) between which you've attempted to create a dependency:" +
                "PROVIDING RECORD: \(providingRecord)\n" +
                "PROVIDING \(typeName.uppercased()): \(providingRecord.databaseWhereStored)\n" +
                "DEPENDENT RECORD: \(dependentRecord)\n" +
                "DEPENDENT \(typeName.uppercased()): \(dependentRecord.databaseWhereStored)\n"
            )
            
        }
        
        if dependentRecord.databaseWhereStored == nil {
            dependentRecord.databaseWhereStored = providingRecord.databaseWhereStored
        } else {
            guard dependentRecord.databaseWhereStored == providingRecord.databaseWhereStored else { mismatchFatalError(with: "database") }
        }
        
        if dependentRecord.recordZone == nil {
            dependentRecord.recordZone = providingRecord.recordZone
        } else {
            guard dependentRecord.recordZone == providingRecord.recordZone else { mismatchFatalError(with: "record zone") }
        }
        
    }
    
    
    // MARK: - Protocol Conformance
    
    var hashValue: Int {
        return self.backingRemoteRecord.hashValue
    }
    
    static func ==(left:Record, right:Record) -> Bool {
        return left.backingRemoteRecord == right.backingRemoteRecord
    }
    
}
