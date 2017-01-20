//
//  Mist.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation
import CloudKit
import UIKit

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

enum NotificationHandlingError : Error {
    
    case dictionaryInproperlyFormed
    case noSubscriptionID
    case unsupportedNotificationType
    
}


class Mist {
    
    
    // MARK: - Configuration Properties
    
    static var config: Configuration = Configuration(
        public: Configuration.Scoped(pullsRecordsMatchingDescriptors: nil),
        private: Configuration.Scoped(pullsRecordsMatchingDescriptors: nil)
    )
    
    
    // MARK: - Public Properties
    
    static private(set) var currentUser: CloudKitUser? = nil
    static private(set) var automaticSyncEnabled: Bool = false
    
    
    // MARK: - Synchronization Settings
    
    static func enableAutomaticSync(_ completion:((RecordOperationResult, SyncSetupSummary?) -> Void)) {
        self.adjustAutomaticSync(true, completion: completion)
    }
    
    static func disableAutomaticSync(_ completion:((RecordOperationResult, SyncSetupSummary?) -> Void)) {
        self.adjustAutomaticSync(false, completion: completion)
    }
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, from:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, Record?) -> Void)) {
        
        var record: Record? = nil
        
        let operation = { record = self.singleton.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWithScope: from, fetchDepth: fetchDepth) }
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult, record)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    static func fetch(_ identifiers:Set<RecordIdentifier>, from:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)) {
        
        var records: Set<Record> = []
        
        let operation = {
            
            for identifier in identifiers {
                
                if let record = self.singleton.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWithScope: from, fetchDepth: fetchDepth) {
                    records.insert(record)
                }
                
            }
        
        }
        
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            
            let recordsArray = Array(records)
            finished(recordOperationResult, recordsArray)
            
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    static func find(
        recordsOfType type:Record.Type?=nil, where filter:FilterClosure, within:StorageScope,
        sortedBy:SortClosure?=nil, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)
    ) {
        
        var records: [Record]? = nil
        
        let operation = { records = self.singleton.localDataCoordinator.retrieveRecords(withType:type, matching: filter, inStorageWithScope: within, fetchDepth: fetchDepth) }
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult, records)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    static func find(
        recordsOfType type:Record.Type?=nil, where predicate:NSPredicate, within:StorageScope,
        sortedBy:SortClosure?=nil, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)
    ) {
        
        var records: [Record]? = nil
        
        let operation = { records = self.singleton.localDataCoordinator.retrieveRecords(withType: type, matching: predicate, inStorageWithScope: within, fetchDepth: fetchDepth) }
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult, records)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record, to:StorageScope, finished:((RecordOperationResult, DirectionalSyncSummary?) -> Void)?=nil) {
        
        let operation = { self.singleton.localDataCoordinator.addRecord(record, toStorageWith: to) }
        self.performUserGuardedOperation(operation, pushScope: to, finished: finished)
        
    }
    
    static func add(_ records:Set<Record>, to:StorageScope, finished:((RecordOperationResult, DirectionalSyncSummary?) -> Void)?=nil) {
        
        let operation = { self.singleton.localDataCoordinator.addRecords(records, toStorageWith: to) }
        self.performUserGuardedOperation(operation, pushScope: to, finished: finished)
        
    }
    
    static func remove(_ record:Record, from:StorageScope, finished:((RecordOperationResult, DirectionalSyncSummary?) -> Void)?=nil) {
        
        let operation = { self.singleton.localDataCoordinator.removeRecord(record, fromStorageWith: from) }
        self.performUserGuardedOperation(operation, pushScope: from, finished: finished)
        
    }
    
    static func remove(_ records:Set<Record>, from:StorageScope, finished:((RecordOperationResult, DirectionalSyncSummary?) -> Void)?=nil) {
        
        let operation = { self.singleton.localDataCoordinator.removeRecords(records, fromStorageWith: from) }
        self.performUserGuardedOperation(operation, pushScope: from, finished: finished)
        
    }
    
    
    // MARK: - Syncing Items
    
    static func sync(_ qOS:QualityOfService?=QualityOfService.default, finished:((SyncSummary) -> Void)?=nil) {
        
        self.singleton.checkCurrentUserStatus { (userExists) in
            
            guard userExists else {
                
                if let finished = finished {
                    
                    let syncSummary = SyncSummary.syncSummaryForPreflightingFailure(withError: self.singleton.noCurrentUserError.errorObject())
                    finished(syncSummary)
                    
                }
                
                return
                
            }
            
            self.singleton.synchronizationCoordinator.sync(qOS, finished: finished)
            
        }
        
    }
    
    // MARK: - Handling Notifications
    
    static func handleNotification(withUserInfo userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)) throws {
        
        guard let dict = userInfo as? [String : NSObject] else {
            throw NotificationHandlingError.dictionaryInproperlyFormed
        }
        
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        
        guard let subscriptionID = notification.subscriptionID else {
            throw NotificationHandlingError.noSubscriptionID
        }
        
        let currentUserCache = self.singleton.localDataCoordinator.currentUserCache
        let publicCache = currentUserCache.publicCache
        let privateCache = currentUserCache.privateCache
        let sharedCache = currentUserCache.sharedCache
        
        switch notification.notificationType {
            
        case .readNotification, .recordZone:
            throw NotificationHandlingError.unsupportedNotificationType
            
        case .database:
            
            if subscriptionID == "private" {
                
                privateCache.handleNotification()
                
            } else if subscriptionID == "shared" {
             
                sharedCache.handleNotification()
                
            } else {
                
                fatalError("The subscriptionID for a database subscription should only ever be of the values 'private' or 'shared', but this one has the value \(subscriptionID)")
                
            }
            
        case .query:
            publicCache.handleNotification()
            
        }
        
    }
    
    
    // MARK: - Internal Properties
    
    internal let remoteDataCoordinator = RemoteDataCoordinator()
    internal let synchronizationCoordinator = SynchronizationCoordinator()
    
    internal let noCurrentUserError = ErrorStruct(
        code: 401, title: "User Not Authenticated",
        failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
        description: "Get the user to log in and try this request again."
    )
    
    
    // MARK: - Internal Functions
    
    internal static func userRecordExists(withIdentifier identifier:RecordIdentifier, finished:((Record?) -> Void)) {
        
        self.singleton.cacheInteractionQueue.addOperation {
            
            let potentiallyExtantUserRecord = self.singleton.localDataCoordinator.userRecordExists(withIdentifier: identifier)
            finished(potentiallyExtantUserRecord)
            
        }
        
    }
    
    internal static func setCurrentUser(_ userRecord:CloudKitUser, finished:((RecordOperationResult) -> Void)) {
        
        self.singleton.cacheInteractionQueue.addOperation {
            
            self.singleton.localDataCoordinator.setCurrentUser(userRecord)
            self.currentUser = userRecord
            
            finished(RecordOperationResult(succeeded: true, error: nil))
            
        }
        
    }
    
    internal static func recordsWithUnpushedChangesAndDeletions(forScope scope:StorageScope, finished:((RecordOperationResult, [Record]?, [Record]?) -> Void)) {
        
        var unpushedChanges: [Record]? = nil
        var unpushedDeletions: [Record]? = nil
        
        let operation = {
            
            for recordZone in self.singleton.localDataCoordinator.currentUserCache.scopedCache(withScope: scope).recordZonesWithUnpushedChanges {
                
            }
            
            let unpushedChangeData = self.singleton.localDataCoordinator.currentUserCache.scopedCache(withScope: scope).recordsWithUnpushedChanges.values
            unpushedChanges = unpushedChangeData.map({ $0 }) // Because Swift compiler is a dumbass
            
            let unpushedDeletionData = self.singleton.localDataCoordinator.currentUserCache.scopedCache(withScope: scope).recordsWithUnpushedDeletions.values
            unpushedDeletions = unpushedDeletionData.map({ $0 }) // Because Swift compiler is a dumbass
            
        }
        
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult, unpushedChanges, unpushedDeletions)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    internal static func internalAdd(_ records:Set<Record>, to:StorageScope, finished:((RecordOperationResult) -> Void)) {
        
        let operation = { self.singleton.localDataCoordinator.addRecords(records, toStorageWith: to) }
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    internal static func internalRemove(_ records:Set<Record>, from:StorageScope, finished:((RecordOperationResult) -> Void)) {
        
        let operation = { self.singleton.localDataCoordinator.removeRecords(records, fromStorageWith: from) }
        let internalFinished: ((RecordOperationResult, DirectionalSyncSummary?) -> Void) = { recordOperationResult, directionalSyncSummary in
            finished(recordOperationResult)
        }
        
        self.performUserGuardedOperation(operation, finished: internalFinished)
        
    }
    
    
    // MARK: - Private Properties
    
    private static let singleton = Mist()
    private let cacheInteractionQueue = Queue()
    private let localDataCoordinator = LocalDataCoordinator()
    
    
    // MARK: - Private Functions
    
    private static func adjustAutomaticSync(_ enableSync:Bool, completion:((RecordOperationResult, SyncSetupSummary?) -> Void)) {
        
        self.refreshAutomaticSyncConfiguration(enableSync) { (recordOperationResult, syncSetupSummary) in
            
            if recordOperationResult.succeeded == true, let syncSetupSummary = syncSetupSummary, syncSetupSummary.result == .success {
                self.automaticSyncEnabled = enableSync
            }
            
            completion(recordOperationResult, syncSetupSummary)
            
        }
        
    }
    
    private static func refreshAutomaticSyncConfiguration(_ syncAutomatically:Bool, completion:((RecordOperationResult, SyncSetupSummary?) -> Void)) {
        
        self.singleton.cacheInteractionQueue.addOperation {
            
            self.singleton.checkCurrentUserStatus { (userExists) in
                
                guard userExists else {
                    
                    completion(RecordOperationResult(succeeded: false, error: self.singleton.noCurrentUserError.errorObject()), nil)
                    return
                    
                }
                
                let currentUserCache = self.singleton.localDataCoordinator.currentUserCache
                let publicCache = currentUserCache.publicCache
                let privateCache = currentUserCache.privateCache
                let sharedCache = currentUserCache.sharedCache
                
                let successfulRecordOperation = RecordOperationResult(succeeded: true, error: nil)
                
                publicCache.adjustQuerySubscriptions(syncAutomatically, completion: { (publicError) in
                    
                    if let publicError = publicError {
                        
                        completion(
                            successfulRecordOperation,
                            SyncSetupSummary(
                                result: .totalFailure,
                                errors: [publicError],
                                publicSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [publicError]),
                                privateSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: []),
                                sharedSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [])
                            )
                        )
                        
                    } else {
                        
                        guard Mist.currentUser != nil else {
                            
                            let noCurrentUserError = self.singleton.noCurrentUserError.errorObject()
                            
                            completion(
                                successfulRecordOperation,
                                SyncSetupSummary(
                                    result: .totalFailure,
                                    errors: [noCurrentUserError],
                                    publicSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [noCurrentUserError]),
                                    privateSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: []),
                                    sharedSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [])
                                )
                            )
                            
                            return
                            
                        }
                        
                        privateCache.adjustDatabaseSubscription(syncAutomatically, completion: { (privateError) in
                            
                            if let privateError = privateError {
                                
                                completion(
                                    successfulRecordOperation,
                                    SyncSetupSummary(
                                        result: .partialFailure,
                                        errors: [privateError],
                                        publicSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: []),
                                        privateSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [privateError]),
                                        sharedSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [])
                                    )
                                )
                                
                            } else {
                                
                                sharedCache.adjustDatabaseSubscription(syncAutomatically, completion: { (sharedError) in
                                    
                                    if let sharedError = sharedError {
                                        
                                        completion(
                                            successfulRecordOperation,
                                            SyncSetupSummary(
                                                result: .partialFailure,
                                                errors: [sharedError],
                                                publicSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: []),
                                                privateSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: []),
                                                sharedSyncSetupSummary: ScopedSyncSetupSummary(result: .totalFailure, errors: [sharedError])
                                            )
                                        )
                                        
                                    } else {
                                        
                                        completion(
                                            successfulRecordOperation,
                                            SyncSetupSummary(
                                                result: .success,
                                                errors: [],
                                                publicSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: []),
                                                privateSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: []),
                                                sharedSyncSetupSummary: ScopedSyncSetupSummary(result: .success, errors: [])
                                            )
                                        )
                                        
                                    }
                                    
                                })
                                
                            }
                            
                        })
                        
                    }
                    
                })
                
            }
            
        }
        
    }
    
    private static func performUserGuardedOperation(_ operation:(() -> Void), pushScope:StorageScope?=nil, finished:((RecordOperationResult, DirectionalSyncSummary?) -> Void)?) {
        
        Mist.singleton.cacheInteractionQueue.addOperation {
            
            self.singleton.checkCurrentUserStatus { (userExists) in
                
                guard userExists else {
                    
                    if let finished = finished {
                        finished(RecordOperationResult(succeeded: false, error: self.singleton.noCurrentUserError.errorObject()), nil)
                    }
                    
                    return
                    
                }
                
                let operationResult = RecordOperationResult(succeeded: true, error: nil)
                
                operation()
                
                if Mist.automaticSyncEnabled == true, let pushScope = pushScope {
                    
                    self.singleton.remoteDataCoordinator.performDatabasePush(for: pushScope, completed: { (directionalSyncSummary) in
                        
                        if let finished = finished {
                            finished(operationResult, directionalSyncSummary)
                        }
                        
                    })
                    
                } else {
                    
                    if let finished = finished {
                        finished(operationResult, nil)
                    }
                    
                }
                
            }
            
        }
        
    }
    
    private func checkCurrentUserStatus(completion:((Bool) -> Void)) {
        
        if Mist.currentUser != nil {
            
            completion(true)
            
        } else {
            
            Mist.singleton.synchronizationCoordinator.refreshUser(completion)
            
        }
        
    }
    
}

