//
//  Mist.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit


typealias StorageScope = CKDatabaseScope
typealias RecordIdentifier = String
typealias RecordZoneIdentifier = String
typealias RelationshipDeleteBehavior = CKReferenceAction
typealias FilterClosure = ((Record) throws -> Bool)
typealias SortClosure = ((Record,Record) throws -> Bool)


struct Configuration {
    
    var `public`: Scoped
    var `private`: Scoped
    
    struct Scoped {
        
        var pullsRecordsMatchingDescriptors: [RecordDescriptor]?
        
    }
    
}

struct RecordDescriptor {
    
    let type: Record.Type
    let descriptor: NSPredicate
    
}


class Mist {
    
    
    // MARK: - Configuration Properties
    
    static var config: Configuration = Configuration(
        public: Configuration.Scoped(pullsRecordsMatchingDescriptors: nil),
        private: Configuration.Scoped(pullsRecordsMatchingDescriptors: nil)
    )
    
    
    // MARK: - Public Properties
    
    // TODO: Implement code to keep this up to date
    static private(set) var currentUser: CloudKitUser? = nil
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, from:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, Record?) -> Void)) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()), nil)
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                let record = self.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWithScope: from, fetchDepth: fetchDepth)
                finished(RecordOperationResult(succeeded: true, error: nil), record)
                
            }
            
        }
        
    }
    
    static func find(
        recordsOfType type:Record.Type?=nil, where filter:FilterClosure, within:StorageScope,
        sortedBy:SortClosure?=nil, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]) -> Void)
    ) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()), [])
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                let records = self.localDataCoordinator.retrieveRecords(withType:type, matching: filter, inStorageWithScope: within, fetchDepth: fetchDepth)
                finished(RecordOperationResult(succeeded: true, error: nil), records)
                
            }
            
        }
        
    }
    
    static func find(
        recordsOfType type:Record.Type?=nil, where predicate:NSPredicate, within:StorageScope,
        sortedBy:SortClosure?=nil, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]) -> Void)
    ) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()), [])
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                let records = self.localDataCoordinator.retrieveRecords(withType: type, matching: predicate, inStorageWithScope: within, fetchDepth: fetchDepth)
                finished(RecordOperationResult(succeeded: true, error: nil), records)
                
            }
            
        }
        
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                self.localDataCoordinator.addRecord(record, toStorageWith: to)
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: true, error: nil))
                }
                
            }
            
        }
        
    }
    
    static func add(_ records:Set<Record>, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                self.localDataCoordinator.addRecords(records, toStorageWith: to)
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: true, error: nil))
                }
                
            }
            
        }
        
    }
    
    static func remove(_ record:Record, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                self.localDataCoordinator.removeRecord(record, fromStorageWith: from)
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: true, error: nil))
                }
                
            }
            
        }
        
    }
    
    static func remove(_ records:Set<Record>, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
            Mist.cacheInteractionQueue.addOperation {
                
                self.localDataCoordinator.removeRecords(records, fromStorageWith: from)
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: true, error: nil))
                }
                
            }
            
        }
        
    }
    
    
    // MARK: - Syncing Items
    
    static func sync(_ qOS:QualityOfService?=QualityOfService.default, finished:((SyncSummary) -> Void)?=nil) {
        
        self.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                // TODO: Call callback with failure
//                if let finished = finished {
//                    finished(RecordOperationResult(succeeded: false, error: self.noCurrentUserError.errorObject()))
//                }
                
                return
                
            }
            
            self.synchronizationCoordinator.sync(qOS, finished: finished)
            
        }
        
    }
    
    
    // MARK: - Internal Properties
    
    internal static let remoteDataCoordinator = RemoteDataCoordinator()
    internal static let synchronizationCoordinator = SynchronizationCoordinator()
    
    internal static let noCurrentUserError = ErrorStruct(
        code: 401, title: "User Not Authenticated",
        failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
        description: "Get the user to log in and try this request again."
    )
    
    
    // MARK: - Internal Functions
    
    internal static func userRecordExists(withIdentifier identifier:RecordIdentifier, finished:((Record?) -> Void)) {
        
        Mist.cacheInteractionQueue.addOperation {
            
            let potentiallyExtantUserRecord = self.localDataCoordinator.userRecordExists(withIdentifier: identifier)
            finished(potentiallyExtantUserRecord)
            
        }
        
    }
    
    internal static func setCurrentUser(_ userRecord:CloudKitUser, finished:((RecordOperationResult) -> Void)) {
        
        Mist.cacheInteractionQueue.addOperation {
            
            self.localDataCoordinator.setCurrentUser(userRecord)
            self.currentUser = userRecord
            
            finished(RecordOperationResult(succeeded: true, error: nil))
            
        }
        
    }
    
    
    // MARK: - Private Properties
    
    private static let cacheInteractionQueue = Queue()
    private static let localDataCoordinator = LocalDataCoordinator()
    
    
    // MARK: - Private Functions
    
    private static func checkCurrentUserStatus(completion:((Bool) -> Void)) {
        
        if self.currentUser != nil {
            
            completion(true)
            
        } else {
            
            let remote = self.remoteDataCoordinator
            remote.confirmICloudAvailable { (result) in
                remote.confirmUserAuthenticated(result, completion: { (result) in
                    remote.confirmUserRecordExists(result, completion: { (result) in
                        completion(result.success)
                    })
                })
            }
            
        }
        
    }
    
}

