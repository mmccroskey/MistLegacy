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
typealias ZoneIdentifier = String

struct Configuration {
    
    var `public`: Scoped
    var `private`: Scoped
    var shared: Scoped
    
    struct Scoped {
        
        var pullRecordsMatchingDescriptors: [RecordDescriptor]?
        
    }
    
}

struct RecordDescriptor {
    
    let type: Record.Type
    let descriptor: NSPredicate
    
}

struct RecordOperationResult {
    
    let succeeded: Bool
    let error: Error?
    
}

enum SyncResult {
    case success
    case partialFailure
    case totalFailure
}

enum SyncDirection {
    case pull
    case push
}

struct SyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    
    let preflightingSummary: PreflightingSyncSummary
    let publicSummary: PublicScopedSyncSummary
    let privateSummary: UserScopedSyncSummary
    let sharedSummary: UserScopedSyncSummary
    
}

struct PreflightingSyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    
}

struct PublicScopedSyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    
    let pullSummary: DirectionalSyncSummary
    let pushSummary: DirectionalSyncSummary
    
}

struct UserScopedSyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    
    let pullSummary: ZoneBasedDirectionalSyncSummary
    let pushSummary: DirectionalSyncSummary
    
}

struct DirectionalSyncSummary {
    
    init(result: SyncResult) {
        
        self.result = result
        
        self.errors = []
        self.idsOfRecordsChanged = []
        self.idsOfRecordsDeleted = []
        
    }
    
    init(result: SyncResult, error: Error) {
        
        self.result = result
        self.errors = [error]
        
        self.idsOfRecordsChanged = []
        self.idsOfRecordsDeleted = []
        
    }
    
    init(result: SyncResult, idsOfRecordsChanged:[RecordIdentifier], idsOfRecordsDeleted:[RecordIdentifier]) {
        
        self.result = result
        self.idsOfRecordsChanged = idsOfRecordsChanged
        self.idsOfRecordsDeleted = idsOfRecordsDeleted
        
        self.errors = []
        
    }
    
    let result: SyncResult
    let errors: [Error]
    let idsOfRecordsChanged: [RecordIdentifier]
    let idsOfRecordsDeleted: [RecordIdentifier]
    
}

struct ZoneBasedDirectionalSyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    let zoneChangeSummary: ZonedSyncSummary?
    let zoneDeletionSummary: ZonedSyncSummary?
    
}

struct ZonedSyncSummary {
    
    let result: SyncResult
    let errors: [Error]
    let idsOfRelevantRecords: [RecordIdentifier]
    
}

internal struct SyncStepResult {
    
    init(success: Bool) {
    
        self.success = success
        
        self.error = nil
        self.value = nil
        
    }
    
    init(success: Bool, error: Error) {
        
        self.success = success
        self.error = error
        
        self.value = nil
        
    }
    
    init(success: Bool, value: Any) {
        
        self.success = success
        self.value = value
        
        self.error = nil
        
    }
    
    let success: Bool
    let error: Error?
    let value: Any?
    
}

internal typealias SyncStepCompletion = ((SyncStepResult) -> Void)

internal struct ErrorStruct {
    
    let code: Int
    let title: String
    let failureReason: String
    let description: String
    
    func errorObject() -> NSError {
        
        return NSError(domain: "MistErrorDomain", code: code, userInfo: [
            NSLocalizedFailureReasonErrorKey : NSLocalizedString(title, value: failureReason, comment: ""),
            NSLocalizedDescriptionKey : NSLocalizedString(title, value: description, comment: "")
            
        ])
        
    }
    
}



// MARK: -



class Mist {
    
    
    // MARK: - Fetching Items
    
    static func get(_ identifier:RecordIdentifier, from:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, Record?) -> Void)) {
        self.localDataCoordinator.retrieveRecord(matching: identifier, fromStorageWithScope: from, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(where filter:((Record) throws -> Bool), within:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: filter, inStorageWithScope: within, fetchDepth: fetchDepth, retrievalCompleted: finished)
    }
    
    static func find(where predicate:NSPredicate, within:StorageScope, fetchDepth:Int = -1, finished:((RecordOperationResult, [Record]?) -> Void)) {
        self.localDataCoordinator.retrieveRecords(matching: predicate, inStorageWithScope: within, fetchDepth:fetchDepth, retrievalCompleted: finished)
    }
    
    
    // MARK: - Modifying Items
    
    static func add(_ record:Record, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.addRecord(record, toStorageWith: to, finished: finished)
    }
    
    static func add(_ records:Set<Record>, to:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.addRecords(records, toStorageWith: to, finished: finished)
    }
    
    static func remove(_ record:Record, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.removeRecord(record, fromStorageWith: from, finished: finished)
    }
    
    static func remove(_ records:Set<Record>, from:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.localDataCoordinator.removeRecords(records, fromStorageWith: from, finished: finished)
    }
    
    
    // MARK: - Syncing Items
    
    static func sync(_ qOS:QualityOfService?=QualityOfService.default, finished:((SyncSummary) -> Void)?=nil) {
        
        func syncSummaryForPreflightingFailure(withError error:Error?) -> SyncSummary {
            
            var errors: [Error] = []
            if let error = error {
                errors.append(error)
            }
            
            let preflightingSummary = PreflightingSyncSummary(result: .totalFailure, errors: errors)
            
            let zonedDirectionalSummary = ZoneBasedDirectionalSyncSummary(result: .totalFailure, errors: [], zoneChangeSummary: nil, zoneDeletionSummary: nil)
            let directionalSummary = DirectionalSyncSummary(result: .totalFailure)
            let userScopedSummary = UserScopedSyncSummary(result: .totalFailure, errors: [], pullSummary: zonedDirectionalSummary, pushSummary: directionalSummary)
            let publicScopedSummary = PublicScopedSyncSummary(result: .totalFailure, errors: [], pullSummary: directionalSummary, pushSummary: directionalSummary)
            
            let summary = SyncSummary(
                result: .totalFailure, errors: errors,
                preflightingSummary: preflightingSummary, publicSummary: publicScopedSummary, privateSummary: userScopedSummary, sharedSummary: userScopedSummary
            )
            
            return summary
            
        }
        
        func syncSummaryFromDependentSummaries(
            _ publicPull:DirectionalSyncSummary?, publicPush:DirectionalSyncSummary?,
            privatePull:ZoneBasedDirectionalSyncSummary?, privatePush:DirectionalSyncSummary?,
            sharedPull:ZoneBasedDirectionalSyncSummary?, sharedPush:DirectionalSyncSummary?
        ) -> SyncSummary {
            
            guard
                let publicPullSummary  = publicPull,  let publicPushSummary  = publicPush,
                let privatePullSummary = privatePull, let privatePushSummary = privatePush,
                let sharedPullSummary  = sharedPull,  let sharedPushSummary  = sharedPush
            else {
                fatalError("Some push summaries were not initialized.")
            }
            
            let preflightingSummary = PreflightingSyncSummary(result: .success, errors: [])
            
            let publicSummaryResult: SyncResult
            if publicPullSummary.result == .success && publicPushSummary.result == .success {
                publicSummaryResult = .success
            } else if publicPullSummary.result == .totalFailure && publicPushSummary.result == .totalFailure {
                publicSummaryResult = .totalFailure
            } else {
                publicSummaryResult = .partialFailure
            }
            
            let publicSummaryErrors = (publicPullSummary.errors + publicPushSummary.errors)
            
            let publicSummary = PublicScopedSyncSummary(
                result: publicSummaryResult, errors: publicSummaryErrors,
                pullSummary: publicPullSummary, pushSummary: publicPushSummary
            )
            
            func syncResultFromChildSummaries(_ pullSummary:ZoneBasedDirectionalSyncSummary, pushSummary:DirectionalSyncSummary) -> SyncResult {
                
                let summaryResult: SyncResult
                if pullSummary.result == .success && pushSummary.result == .success {
                    summaryResult = .success
                } else if pullSummary.result == .totalFailure && pushSummary.result == .totalFailure {
                    summaryResult = .totalFailure
                } else {
                    summaryResult = .partialFailure
                }
                
                return summaryResult
                
            }
            
            let privateSyncResult = syncResultFromChildSummaries(privatePullSummary, pushSummary: privatePushSummary)
            let privateErrors = (privatePullSummary.errors + privatePushSummary.errors)
            
            let privateSummary = UserScopedSyncSummary(
                result: privateSyncResult, errors: privateErrors,
                pullSummary: privatePullSummary, pushSummary: privatePushSummary
            )
            
            let sharedSyncResult = syncResultFromChildSummaries(sharedPullSummary, pushSummary: sharedPushSummary)
            let sharedErrors = (sharedPullSummary.errors + sharedPushSummary.errors)
            
            let sharedSummary = UserScopedSyncSummary(
                result: sharedSyncResult, errors: sharedErrors,
                pullSummary: sharedPullSummary, pushSummary: sharedPushSummary
            )
            
            let masterSyncResult: SyncResult
            if preflightingSummary.result == .success && publicSummary.result == .success && privateSummary.result == .success && sharedSummary.result == .success {
                
                masterSyncResult = .success
                
            } else if preflightingSummary.result == .totalFailure && publicSummary.result == .totalFailure &&
                privateSummary.result == .totalFailure && sharedSummary.result == .totalFailure {
                
                masterSyncResult = .totalFailure
                
            } else {
                
                masterSyncResult = .partialFailure
                
            }
            
            let masterErrors = (preflightingSummary.errors + publicSummary.errors + privateSummary.errors + sharedSummary.errors)
            
            let masterSummary = SyncSummary(
                result: masterSyncResult, errors: masterErrors, preflightingSummary: preflightingSummary,
                publicSummary: publicSummary, privateSummary: privateSummary, sharedSummary: sharedSummary
            )
            
            return masterSummary
            
        }
        
        let remote = self.remoteDataCoordinator
        remote.confirmICloudAvailable { (result) in
            remote.confirmUserAuthenticated(result, completion: { (result) in
                remote.confirmUserRecordExists(result, completion: { (result) in
                    
                    guard result.success == true else {
                        
                        if let finished = finished {
                            finished(syncSummaryForPreflightingFailure(withError: result.error))
                        }
                        
                        return
                        
                    }
                    
                    var publicPullSummary: DirectionalSyncSummary?
                    var publicPushSummary: DirectionalSyncSummary?
                    var privatePullSummary: ZoneBasedDirectionalSyncSummary?
                    var privatePushSummary: DirectionalSyncSummary?
                    var sharedPullSummary: ZoneBasedDirectionalSyncSummary?
                    var sharedPushSummary: DirectionalSyncSummary?
                    
                    remote.performPublicDatabasePull({ (returnedPublicPullSummary) in
                        
                        publicPullSummary = returnedPublicPullSummary
                        
                        remote.performPublicDatabasePush({ (returnedPublicPushSummary) in
                            
                            publicPushSummary = returnedPublicPushSummary
                            
                            remote.performDatabasePull(for: .private, completed: { (returnedPrivatePullSummary) in
                                
                                privatePullSummary = returnedPrivatePullSummary
                                
                                remote.performDatabasePush(for: .private, completed: { (returnedPrivatePushSummary) in
                                    
                                    privatePushSummary = returnedPrivatePushSummary
                                    
                                    remote.performDatabasePull(for: .shared, completed: { (returnedSharedPullSummary) in
                                        
                                        sharedPullSummary = returnedSharedPullSummary
                                        
                                        remote.performDatabasePush(for: .shared, completed: { (returnedSharedPushSummary) in
                                            
                                            sharedPushSummary = returnedSharedPushSummary
                                            
                                            let masterSummary = syncSummaryFromDependentSummaries(
                                                publicPullSummary, publicPush: publicPushSummary,
                                                privatePull: privatePullSummary, privatePush: privatePushSummary,
                                                sharedPull: sharedPullSummary, sharedPush: sharedPushSummary
                                            )
                                            
                                            if let finished = finished {
                                                finished(masterSummary)
                                            }
                                            
                                        })
                                        
                                    })
                                    
                                })
                                
                            })
                            
                        })
                        
                    })
                    
                })
            })
        }
        
    }
    
    
    // MARK: - Configuration Properties
    
    static var localRecordStorage: LocalRecordStorage = InMemoryStorage()
    static var localMetadataStorage: LocalMetadataStorage = InMemoryStorage()
    static var localCachedRecordChangesStorage: LocalCachedRecordChangesStorage = InMemoryStorage()
    
    static var config: Configuration = Configuration(
        public: Configuration.Scoped(pullRecordsMatchingDescriptors: nil),
        private: Configuration.Scoped(pullRecordsMatchingDescriptors: nil),
        shared: Configuration.Scoped(pullRecordsMatchingDescriptors: nil)
    )
    
    
    // MARK: - Internal Properties
    
    internal static let localRecordsQueue = Queue()
    internal static let localMetadataQueue = Queue()
    internal static let localCachedRecordChangesQueue = Queue()
    
    internal static let localDataCoordinator = LocalDataCoordinator()
    internal static let remoteDataCoordinator = RemoteDataCoordinator()
    
}



// MARK: - 



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



// MARK: - 



internal class DataCoordinator {
    
    
    // MARK: - Private Properties
    
    private var typeString: String {
        
        let mirror = Mirror(reflecting: self)
        let selfType = mirror.subjectType as! Record.Type
        let typeString = String(describing: selfType)
        
        return typeString
        
    }
    
    
    // MARK: - Public Functions
    
    func metadata(forKey key:String, retrievalCompleted:((Any?) -> Void)) {
        
        var metadata: Any?
        
        let execution = {
            
            if let selfMetadata = Mist.localMetadataStorage.value(forKey: self.typeString) as? [String : Any?] {
                metadata = selfMetadata[key]
            }
            
            metadata = nil
            
        }
        
        let completion = { retrievalCompleted(metadata) }
        
        Mist.localMetadataQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func setMetadata(_ metadata:Any?, forKey key:String) {
        
        Mist.localMetadataQueue.addOperation  {
            
            if var selfMetadata = Mist.localMetadataStorage.value(forKey: self.typeString) as? [String : Any?] {
                
                selfMetadata[key] = metadata
                Mist.localMetadataStorage.setValue(selfMetadata, forKey: self.typeString)
                
            }
            
        }
        
    }
    
}



internal class LocalDataCoordinator : DataCoordinator {

    
    // MARK: - Private Properties
    
    // TODO: Implement code to keep this up to date
    private var currentUser: CloudKitUser? = CloudKitUser()
    
    private var publicRetrievedRecordsCache: [RecordIdentifier : Record] = [:]
    private var userRetrievedRecordsCache: [RecordIdentifier : [StorageScope : [RecordIdentifier : Record]]] = [:]
    
    private enum RecordChangeType {
        case addition
        case removal
    }
    
    
    // MARK: - Fetching Locally-Cached Items
    
    private func scopedRecordsCacheForUser(identifiedBy userRecordIdentifier:RecordIdentifier, withScope scope:StorageScope) -> [RecordIdentifier : Record] {
        
        guard scope != .public else {
            fatalError("Public records are not associated with a User before being added to the local record cache.")
        }
        
        let potentialExistingStorageForUser: [StorageScope : [RecordIdentifier : Record]]? = self.userRetrievedRecordsCache[userRecordIdentifier]
        
        var storageForUser: [StorageScope : [RecordIdentifier : Record]]
        if let existingStorageForUser = potentialExistingStorageForUser {
            storageForUser = existingStorageForUser
        } else {
            storageForUser = [:]
        }
        self.userRetrievedRecordsCache[userRecordIdentifier] = storageForUser
        
        let potentialScopedStorageForUser: [RecordIdentifier : Record]? = self.userRetrievedRecordsCache[userRecordIdentifier]?[scope]
        
        var scopedStorageForUser: [RecordIdentifier : Record]
        if let existingScopedStorageForUser = potentialScopedStorageForUser {
            scopedStorageForUser = existingScopedStorageForUser
        } else {
            scopedStorageForUser = [:]
        }
        
        return scopedStorageForUser
        
    }
    
    private func associateRelatedRecords(for record:Record?, in scope:StorageScope, using fetchDepth:Int, finished:((RecordOperationResult) -> Void)) {
        
        var success = true
        
        if let record = record, fetchDepth != 0 {
            
            for relatedRecordDataSetKeyPair in record.relatedRecordDataSetKeyPairs {
                
                let propertyName = relatedRecordDataSetKeyPair.key
                let identifier = relatedRecordDataSetKeyPair.value.identifier
                let action = relatedRecordDataSetKeyPair.value.action
                
                let newFetchDepth: Int
                if fetchDepth > 0 {
                    newFetchDepth = (fetchDepth - 1)
                } else {
                    newFetchDepth = fetchDepth
                }
                
                self.retrieveRecord(matching: identifier, fromStorageWithScope: scope, fetchDepth: newFetchDepth, retrievalCompleted: { (result, fetchedRecord) in
                    
                    guard success == true else {
                        return
                    }
                    
                    guard result.succeeded == true else {
                        
                        success = false
                        finished(result)
                        return
                        
                    }
                    
                    if let relatedRecord = fetchedRecord {
                        record.setRelatedRecord(relatedRecord, forKey: propertyName, withRelationshipDeleteBehavior: action)
                    }
                    
                })
                
            }
            
        } else {
            
            finished(RecordOperationResult(succeeded: true, error: nil))
            
        }
        
    }

    
    func retrieveRecord(
        matching identifier:RecordIdentifier, fromStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, Record?) -> Void)) {
        
        var result: RecordOperationResult? = nil
        var record: Record? = nil
        
        let execution = {
            
            if scope == .public {
                
                if let cachedRecord = self.publicRetrievedRecordsCache[identifier] {
                    
                    record = cachedRecord
                    
                } else {
                    
                    record = Mist.localRecordStorage.publicRecord(matching: identifier)
                    self.publicRetrievedRecordsCache[identifier] = record
                    
                }
                
            } else {
                
                guard let currentUserIdentifier = self.currentUser?.identifier else {
                    
                    let noCurrentUserError = ErrorStruct(
                        code: 401, title: "User Not Authenticated",
                        failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                        description: "Get the user to log in and try this request again."
                    )
                    
                    result = RecordOperationResult(succeeded: false, error: noCurrentUserError.errorObject())
                    return
                    
                }
                
                var userScopedRecordsCache = self.scopedRecordsCacheForUser(identifiedBy: currentUserIdentifier, withScope: scope)
                if let cachedRecord = userScopedRecordsCache[identifier] {
                    
                    record = cachedRecord
                    
                } else {
                    
                    record = Mist.localRecordStorage.userRecord(matching: identifier, identifiedBy: currentUserIdentifier, inScope: scope)
                    
                    userScopedRecordsCache[identifier] = record
                    self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = userScopedRecordsCache
                    
                }
                
            }
            
            self.associateRelatedRecords(for: record, in: scope, using: fetchDepth, finished: { (operationResult) in
                result = operationResult
            })
            
        }
        
        let completion = {
            
            guard let result = result else {
                fatalError("RecordOperationResult should have been set at this point.")
            }
            
            retrievalCompleted(result, record)
        
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(
        matching filter:((Record) throws -> Bool), inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        var success: Bool = true
        var error: Error?
        var records: [Record] = []
        
        let execution = {
            
            do {
                
                if scope == .public {
                    
                    let cachedRecords = try self.publicRetrievedRecordsCache.values.filter(filter)
                    if cachedRecords.count > 0 {
                        
                        records = cachedRecords
                        
                    } else {
                        
                        try records = Mist.localRecordStorage.publicRecords(matching: filter)
                        
                        for record in records {
                            self.publicRetrievedRecordsCache[record.identifier] = record
                        }
                        
                    }
                    
                } else {
                    
                    guard let currentUserIdentifier = self.currentUser?.identifier else {
                        
                        let noCurrentUserError = ErrorStruct(
                            code: 401, title: "User Not Authenticated",
                            failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                            description: "Get the user to log in and try this request again."
                        )
                        
                        success = false
                        error = noCurrentUserError.errorObject()
                        
                        return
                        
                    }
                    
                    
                    var userScopedRecordsCache = self.scopedRecordsCacheForUser(identifiedBy: currentUserIdentifier, withScope: scope)
                    let cachedRecords = try userScopedRecordsCache.values.filter(filter)
                    if cachedRecords.count > 0 {
                        
                        records = cachedRecords
                        
                    } else {
                        
                        try records = Mist.localRecordStorage.userRecords(matching: filter, identifiedBy: currentUserIdentifier, inScope: scope)
                        
                        for record in records {
                            userScopedRecordsCache[record.identifier] = record
                        }
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = userScopedRecordsCache
                        
                    }
                    
                }
                
                for record in records {
                    
                    self.associateRelatedRecords(for: record, in: scope, using: fetchDepth, finished: { (operationResult) in
                        
                        guard operationResult.succeeded == true else {
                            
                            success = false
                            error = operationResult.error
                            
                            return
                            
                        }
                        
                    })
                    
                }
                
            } catch let fetchError {
                
                error = fetchError
                
            }
            
        }
        
        let completion = {
            
            let result = RecordOperationResult(succeeded: success, error: error)
            retrievalCompleted(result, records)
        
        }
        
        Mist.localRecordsQueue.addOperation(withExecutionBlock: execution, completionBlock: completion)
        
    }
    
    func retrieveRecords(
        matching predicate:NSPredicate, inStorageWithScope scope:StorageScope,
        fetchDepth:Int, retrievalCompleted:((RecordOperationResult, [Record]?) -> Void)) {
        
        self.retrieveRecords(matching: { predicate.evaluate(with: $0) }, inStorageWithScope: scope, fetchDepth: fetchDepth, retrievalCompleted: retrievalCompleted)
        
    }
    
    
    // MARK: - Making Local Changes
    
    func addRecord(_ record:Record, toStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.addRecords(Set([record]), toStorageWith: scope, finished: finished)
    }
    
    func addRecords(_ records:Set<Record>, toStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.performChange(ofType: .addition, on: records, within: scope, finished: finished)
    }
    
    func removeRecord(_ record:Record, fromStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.removeRecords(Set([record]), fromStorageWith: scope, finished: finished)
    }
    
    func removeRecords(_ records:Set<Record>, fromStorageWith scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        self.performChange(ofType: .removal, on: records, within: scope, finished: finished)
    }
    
    private func performChange(ofType changeType:RecordChangeType, on records:Set<Record>, within scope:StorageScope, finished:((RecordOperationResult) -> Void)?=nil) {
        
        if scope == .private || scope == .shared {
            
            guard self.currentUser != nil else {
                
                let noCurrentUserError = ErrorStruct(
                    code: 401, title: "User Not Authenticated",
                    failureReason: "The user is not currently logged in to iCloud. The user must be logged in in order for us to save data to the private or shared scopes.",
                    description: "Get the user to log in and try this request again."
                )
                
                if let finished = finished {
                    finished(RecordOperationResult(succeeded: false, error: noCurrentUserError.errorObject()))
                }
                
                return
                
            }
            
        }
        
        var recordOperationResult: RecordOperationResult?
        
        Mist.localRecordsQueue.addOperation {
            
            for record in records {
                
                switch changeType {
                    
                case .addition:
                    
                    guard ((record.scope == nil) || (record.scope == scope)) else {
                        fatalError("The Record cannot be saved to the \(scope) scope -- it's already saved in the \(record.scope) scope.")
                    }
                    
                    record.scope = scope
                    
                    if scope == .private && record.recordZone == nil {
                        
                        guard let currentUser = self.currentUser else {
                            fatalError("We're trying to create a zone with the current User as the User, but no current User exists.")
                        }
                        
                        let recordZoneID = CKRecordZoneID(zoneName: UUID().uuidString, ownerName: currentUser.identifier)
                        let recordZone = CKRecordZone(zoneID: recordZoneID)
                        record.recordZone = recordZone
                        
                    }
                    
                    switch scope {
                        
                    case .public:
                        
                        guard record.recordZone == nil else {
                            fatalError("Records with custom zones cannot be added to the public scope; the public scope doesn't support custom zones.")
                        }
                        
                        guard record.share == nil else {
                            fatalError("Records with associated shares cannot be added to the public scope; the public scope doesn't support shares.")
                        }
                        
                    case .shared:
                        
                        guard record.share != nil || record.parent != nil else {
                            fatalError("Every Record stored in the shared scope must have an associated share, or a parent, or both.")
                        }
                        
                    case .private:
                        break
                        
                    }
                    
                    let relatedRecords = Set(record.relatedRecordsCache.values)
                    let children = record.children
                    let associatedRecords = relatedRecords.union(children)
                    for associatedRecord in associatedRecords {
                        
                        Record.ensureDatabasesAndRecordZonesMatch(between: record, and: associatedRecord)
                        
                        let identifier = associatedRecord.identifier
                        
                        self.retrieveRecord(matching: identifier, fromStorageWithScope: scope, fetchDepth: -1, retrievalCompleted: { (result, record) in
                            
                            guard result.succeeded == true else {
                                
                                if recordOperationResult == nil {
                                    recordOperationResult = result
                                }
                                
                                return
                                
                            }
                            
                            if record == nil {
                                
                                self.addRecord(associatedRecord, toStorageWith: scope, finished: { (associatedRecordResult) in
                                    
                                    guard associatedRecordResult.succeeded == true else {
                                        
                                        if recordOperationResult == nil {
                                            recordOperationResult = associatedRecordResult
                                        }
                                        
                                        return
                                        
                                    }
                                    
                                })
                                
                            }
                            
                        })
                        
                    }
                    
                    if scope == .public {
                        
                        self.publicRetrievedRecordsCache[record.identifier] = record
                        Mist.localRecordStorage.addPublicRecord(record)
                        
                        Mist.localCachedRecordChangesStorage.publicModifiedRecordsAwaitingPushToCloud.insert(record)
                        
                    } else {
                        
                        let currentUserIdentifier = self.currentUser!.identifier
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]! = [record.identifier : record]
                        Mist.localRecordStorage.addUserRecord(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        
                        Mist.localCachedRecordChangesStorage.addUserModifiedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        
                    }
                    
                case .removal:
                    
                    if scope == .public {
                        
                        self.publicRetrievedRecordsCache.removeValue(forKey: record.identifier)
                        Mist.localRecordStorage.removePublicRecord(record)
                        
                        Mist.localCachedRecordChangesStorage.publicDeletedRecordsAwaitingPushToCloud.insert(record)
                        Mist.localCachedRecordChangesStorage.publicModifiedRecordsAwaitingPushToCloud.remove(record)
                        
                    } else {
                        
                        let currentUserIdentifier = self.currentUser!.identifier
                        
                        self.userRetrievedRecordsCache[currentUserIdentifier]![scope]!.removeValue(forKey: record.identifier)
                        Mist.localRecordStorage.removeUserRecord(matching: record.identifier, identifiedBy: currentUserIdentifier, fromScope: scope)
                        
                        Mist.localCachedRecordChangesStorage.addUserDeletedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, toScope: scope)
                        Mist.localCachedRecordChangesStorage.removeUserModifiedRecordAwaitingPushToCloud(record, identifiedBy: currentUserIdentifier, fromScope: scope)
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
}



// MARK: - 



internal class RemoteDataCoordinator : DataCoordinator {
    
    private class CKRecordSet {
        
        convenience init(records: [CKRecord]) {
            self.init()
            self.records = records
        }
        
        private(set) var records: [CKRecord] = []
        
        func insert(_ record:CKRecord) {
            
            // Remove the record from the array if it's already in there
            remove(record)
            
            records.append(record)
            
        }
        
        func remove(_ record:CKRecord) {
            
            records = records.filter({ (recordInArray) -> Bool in
                return recordInArray.recordID.recordName != record.recordID.recordName
            })
            
        }
        
        func union(_ otherRecordSet:CKRecordSet) -> CKRecordSet {
            
            let selfCopy = CKRecordSet(records: records)
            
            let recordsFromOtherSet = otherRecordSet.records
            for recordFromOtherSet in recordsFromOtherSet {
                
                selfCopy.insert(recordFromOtherSet)
                
            }
            
            return selfCopy
            
        }
        
        func recordIDs() -> [CKRecordID] {
            
            let recordIds = records.map { (record) -> CKRecordID in
                return record.recordID
            }
            
            return recordIds
            
        }
        
    }
    
    
    // MARK: - Private Variables and Metadata Accessors
    
    
    // MARK: Container
    
    private let container = CKContainer.default()
    
    
    // MARK: Databases
    
    private func database(forScope scope:CKDatabaseScope) -> CKDatabase {
        
        switch scope {
            
        case .public:
            return self.container.publicCloudDatabase
            
        case .private:
            return self.container.privateCloudDatabase
            
        case .shared:
            return self.container.sharedCloudDatabase
            
        }
        
    }
    
    
    // MARK: Database Server Change Tokens
    
    private func databaseServerChangeToken(forScope scope:CKDatabaseScope, retrievalCompleted:((CKServerChangeToken?) -> Void)) {
        
        if let key = self.databaseServerChangeTokenKey(forScope: scope) {
            
            self.metadata(forKey: key, retrievalCompleted: { (value) in
                
                if let existingChangeToken = value as? CKServerChangeToken {
                    retrievalCompleted(existingChangeToken)
                } else {
                    retrievalCompleted(nil)
                }
                
            })
            
        }
        
    }
    
    private func setDatabaseServerChangeToken(_ changeToken:CKServerChangeToken?, forScope scope:CKDatabaseScope) {
        
        if let key = self.databaseServerChangeTokenKey(forScope: scope) {
            self.setMetadata(changeToken, forKey: key)
        }
        
    }
    
    private func databaseServerChangeTokenKey(forScope scope:CKDatabaseScope) -> String? {
        
        let key: String?
        
        switch scope {
            
        case .private:
            key = "privateDatabaseServerChangeToken"
            
        case .shared:
            key = "sharedDatabaseServerChangeToken"
            
        default:
            key = nil
            
        }
        
        return key
        
    }
    
    
    // MARK: Record Zone Server Change Tokens
    
    private typealias RecordZoneIdentifier = String
    
    private func recordZonesServerChangeTokens(forScope scope:CKDatabaseScope, retrievalCompleted:(([RecordZoneIdentifier : CKServerChangeToken?]) -> Void)) {
        
        if let key = self.recordZonesServerChangeTokensKey(forScope: scope) {
            
            self.metadata(forKey: key, retrievalCompleted: { (value) in
                
                if let existingChangeTokens = value as? [RecordZoneIdentifier : CKServerChangeToken?] {
                    retrievalCompleted(existingChangeTokens)
                } else {
                    retrievalCompleted([:])
                }
                
            })
            
        }
        
    }
    
    private func setRecordZonesServerChangeTokens(_ changeTokens:[RecordZoneIdentifier : CKServerChangeToken?], forScope scope:CKDatabaseScope) {
        
        if let key = self.recordZonesServerChangeTokensKey(forScope: scope) {
            self.setMetadata(changeTokens, forKey: key)
        }
        
    }
    
    private func recordZonesServerChangeTokensKey(forScope scope:CKDatabaseScope) -> String? {
        
        let key: String?
        
        switch scope {
            
        case .private:
            key = "privateRecordZonesServerChangeToken"
            
        case .shared:
            key = "sharedRecordZonesServerChangeToken"
            
        default:
            key = nil
            
        }
        
        return key
        
    }
    
    
    // MARK: - Preflighting
    
    func confirmICloudAvailable(_ completion:SyncStepCompletion) {
        
        self.container.accountStatus { (status, error) in
            
            guard error == nil else {
                
                completion(SyncStepResult(success: false, error: error!))
                return
                
            }
            
            switch status {
                
            case .available:
                completion(SyncStepResult(success: true))
                
            case .noAccount:
                
                let noAccountError = ErrorStruct(
                    code: 404, title: "No Account",
                    failureReason: "The User is not logged in to iCloud.",
                    description: "Ask the User to log in to iCloud."
                )
                
                completion(SyncStepResult(success: false, error: noAccountError.errorObject()))
                
            case .restricted:
                
                let accountAccessRestrictedError = ErrorStruct(
                    code: 403, title: "iCloud Account Restricted",
                    failureReason: "The User's iCloud account is not authorized for use with CloudKit due to parental control or enterprise (MDM) device restrictions.",
                    description: "Ask the User to adjust their parental controls or enterprise device (MDM) settings."
                )
                
                completion(SyncStepResult(success: false, error: accountAccessRestrictedError.errorObject()))
                
            case .couldNotDetermine:
                
                let indeterminateError = ErrorStruct(
                    code: 500, title: "Unexpected Error",
                    failureReason: "The User's iCloud account status is unknown, but CloudKit has failed to provide an error describing why.",
                    description: "Please try this request again later."
                )
                
                completion(SyncStepResult(success: false, error: indeterminateError.errorObject()))
                
            }
            
        }
        
    }
    
    func confirmUserAuthenticated(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        guard previousResult.success == true else {
            completion(previousResult)
            return
        }
        
        CKContainer.default().fetchUserRecordID { (recordId, error) in
            
            guard error == nil else {
                completion(SyncStepResult(success: false, error: error!))
                return
            }
            
            guard let recordId = recordId else {
                
                let indeterminateError = ErrorStruct(
                    code: 404, title: "User Record Not Found on Server",
                    failureReason: "CloudKit failed to return a User record with the ID that CloudKit itself provided. This shouldn't happen.",
                    description: "Please try this request again later."
                )
                
                completion(SyncStepResult(success: false, error: indeterminateError.errorObject()))
                
                return
                
            }
            
            completion(SyncStepResult(success: true, value: recordId))
            
        }
    
    }
    
    func confirmUserRecordExists(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        guard previousResult.success == true else {
            completion(previousResult)
            return
        }
        
        guard let recordId = previousResult.value as? CKRecordID else {
            fatalError("Formatting of content from confirmUserAuthenticated doesn't match expectations.")
        }
    
        let publicDatabase = self.container.publicCloudDatabase
        publicDatabase.fetch(withRecordID: recordId, completionHandler: { (record, error) in
            
            guard error == nil else {
                completion(SyncStepResult(success: false, error: error!))
                return
            }
            
            // TODO: Handle case where User has changed
            let user = CloudKitUser(backingRemoteRecord: record)
            Mist.add(user, to: .public)
            
            completion(SyncStepResult(success: true))
            
        })
    
    }
    
    
    // MARK: - Updating Local Content with Changes from Remote
    
    func performPublicDatabasePull(_ completed:((DirectionalSyncSummary) -> Void)) {
        
        guard let descriptors = Mist.config.public.pullRecordsMatchingDescriptors else {
            completed(DirectionalSyncSummary(result: .success))
            return
        }
        
        // TODO: Actually pull data matching descriptors
        completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: [], idsOfRecordsDeleted: []))
        
    }
    
    func performDatabasePull(for scope:CKDatabaseScope, completed:((ZoneBasedDirectionalSyncSummary) -> Void)) {
        
        func errorsArray(from optionalError:Error?) -> [Error] {
            
            var errors: [Error] = []
            if let error = optionalError {
                errors.append(error)
            }
            
            return errors
            
        }
        
        func deleteInvalidatedZones(forZonesWithIds idsOfZonesToDelete: Set<CKRecordZoneID>, completed:((ZonedSyncSummary) -> Void)) {
            
            let recordInADeletedZone: ((Record) throws -> Bool) = { (record) in
                
                if let recordZone = record.recordZone {
                    return idsOfZonesToDelete.contains(recordZone.zoneID)
                }
                
                return false
                
            }
            
            Mist.localDataCoordinator.retrieveRecords(matching: recordInADeletedZone, inStorageWithScope: scope, fetchDepth: -1) { (operationResult, records) in
                
                guard operationResult.succeeded == true else {
                    
                    let errors = errorsArray(from: operationResult.error)
                    completed(ZonedSyncSummary(result: .totalFailure, errors: errors, idsOfRelevantRecords: []))
                    
                    return
                    
                }
                
                if let records = records {
                    
                    let recordsSet = Set(records)
                    
                    Mist.localDataCoordinator.removeRecords(recordsSet, fromStorageWith: scope, finished: { (removeOperationResult) in
                        
                        let recordIds = recordsSet.map({ $0.identifier })
                        
                        guard removeOperationResult.succeeded == true else {
                            
                            let errors = errorsArray(from: removeOperationResult.error)
                            completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                            
                            return
                            
                        }
                        
                        completed(ZonedSyncSummary(result: .success, errors:[], idsOfRelevantRecords: recordIds))
                        
                    })
                    
                }
                
            }
            
        }
        
        func fetchZoneChanges(forZonesWithIds idsOfZonesToFetch: Set<CKRecordZoneID>, completed:((ZonedSyncSummary) -> Void)) {
            
            self.recordZonesServerChangeTokens(forScope: scope) { (zoneIdTokenPairs) in
                
                let optionsByRecordZoneId: [CKRecordZoneID : CKFetchRecordZoneChangesOptions] = [:]

                // TODO: Scope metadata to user like other data so we can store server tokens for zones
                
                /*
                for zoneIdTokenPair in zoneIdTokenPairs {
                    
                    let recordZoneID = CKRecordZoneID(
                    
                    let zoneChangesOptionsInstance = CKFetchRecordZoneChangesOptions()
                    zoneChangesOptionsInstance.previousServerChangeToken = zoneIdTokenPair.value
                    optionsByRecordZoneId[zoneIdTokenPair.key] = zoneChangesOptionsInstance
                    
                }
                 */
                
                let changesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: Array(idsOfZonesToFetch), optionsByRecordZoneID: optionsByRecordZoneId)
                
                let changedRecords: CKRecordSet = CKRecordSet()
                var idsOfDeletedRecords: Set<CKRecordID> = []
                
                changesOperation.fetchAllChanges = true
                changesOperation.recordChangedBlock = { record in changedRecords.insert(record) }
                changesOperation.recordWithIDWasDeletedBlock = { (idOfDeletedRecord, string) in idsOfDeletedRecords.insert(idOfDeletedRecord) }
                changesOperation.recordZoneChangeTokensUpdatedBlock = { (recordZoneId, serverChangeToken, clientChangeTokenData) in
                    
                    // TODO: Scope metadata to user like other data so we can store server tokens for zones
                    
                    /*
                    if let serverChangeToken = serverChangeToken {
                        self.setServerChangeToken(serverChangeToken, forRecordZoneWithId: recordZoneId)
                    } else {
                        self.setServerChangeToken(nil, forRecordZoneWithId: recordZoneId)
                    }
                     */
                    
                }
                
                changesOperation.fetchRecordZoneChangesCompletionBlock = { error in
                    
                    guard error == nil else {
                        
                        completed(ZonedSyncSummary(result: .totalFailure, errors: [error!], idsOfRelevantRecords: []))
                        return
                        
                    }
                    
                    let recordIdentifiersForDeletedRecords = idsOfDeletedRecords.map({ $0.recordName }) as [RecordIdentifier]
                    
                    Mist.localDataCoordinator.retrieveRecords(
                        matching: { recordIdentifiersForDeletedRecords.contains($0.identifier) }, inStorageWithScope: scope, fetchDepth: -1,
                        retrievalCompleted: { (fetchOperationResult, records) in
                            
                            var recordIds: [RecordIdentifier] = []
                            var recordsSet: Set<Record> = []
                            if let records = records {
                                recordIds = records.map({ $0.identifier })
                                recordsSet = Set(records)
                            }
                        
                            guard fetchOperationResult.succeeded == true else {
                                
                                let errors = errorsArray(from: fetchOperationResult.error)
                                completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                                
                                return
                                
                            }
                            
                            Mist.localDataCoordinator.removeRecords(recordsSet, fromStorageWith: scope, finished: { (removeOperationResult) in
                                
                                let recordIds = recordsSet.map({ $0.identifier })
                                
                                guard removeOperationResult.succeeded == true else {
                                    
                                    let errors = errorsArray(from: removeOperationResult.error)
                                    completed(ZonedSyncSummary(result: .partialFailure, errors: errors, idsOfRelevantRecords: recordIds))
                                    
                                    return
                                    
                                }
                                
                                completed(ZonedSyncSummary(result: .success, errors:[], idsOfRelevantRecords: recordIds))
                                
                            })
                        
                    })
                    
                }
                
            }
            
        }
        
        self.databaseServerChangeToken(forScope: scope, retrievalCompleted: { (token) in
            
            let databaseChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)
            
            var idsOfZonesToFetch: Set<CKRecordZoneID> = []
            var idsOfZonesToDelete: Set<CKRecordZoneID> = []

            databaseChangesOperation.fetchAllChanges = true
            databaseChangesOperation.recordZoneWithIDChangedBlock = { recordZoneId in idsOfZonesToFetch.insert(recordZoneId) }
            databaseChangesOperation.recordZoneWithIDWasDeletedBlock = { recordZoneId in idsOfZonesToDelete.insert(recordZoneId) }
            databaseChangesOperation.changeTokenUpdatedBlock = { self.setDatabaseServerChangeToken($0, forScope: scope) }
            
            databaseChangesOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) in

                guard error == nil else {
                    completed(ZoneBasedDirectionalSyncSummary(result: .totalFailure, errors: [error!], zoneChangeSummary: nil, zoneDeletionSummary: nil))
                    return
                }

                if let newToken = newToken {
                    self.setDatabaseServerChangeToken(newToken, forScope: scope)
                }
                
                deleteInvalidatedZones(forZonesWithIds: idsOfZonesToDelete, completed: { (zonedDeletionSummary) in
                    
                    guard zonedDeletionSummary.result == .success else {
                        
                        completed(ZoneBasedDirectionalSyncSummary(
                            result: .totalFailure, errors: zonedDeletionSummary.errors, zoneChangeSummary: nil, zoneDeletionSummary: zonedDeletionSummary
                        ))
                        
                        return
                        
                    }
                    
                    fetchZoneChanges(forZonesWithIds: idsOfZonesToFetch, completed: { (zonedChangesSummary) in
                        
                        guard zonedChangesSummary.result == .success else {
                            
                            completed(ZoneBasedDirectionalSyncSummary(
                                result: .totalFailure, errors: zonedChangesSummary.errors, zoneChangeSummary: zonedChangesSummary, zoneDeletionSummary: zonedDeletionSummary
                            ))
                            
                            return
                            
                        }
                        
                        completed(ZoneBasedDirectionalSyncSummary(
                            result: .success, errors: [], zoneChangeSummary: zonedChangesSummary, zoneDeletionSummary: zonedDeletionSummary
                        ))
                        
                    })
                    
                })

            }
            
            let database = self.database(forScope: scope)
            database.add(databaseChangesOperation)


        })
        
    }
    
    
    // MARK: - Updating Remote Content with Changes from Local
    
    func performPublicDatabasePush(_ completed:((DirectionalSyncSummary) -> Void)) {
        
        // TODO: Actually push data
        completed(DirectionalSyncSummary(result: .success, idsOfRecordsChanged: [], idsOfRecordsDeleted: []))
        
    }
    
    func performDatabasePush(for scope:CKDatabaseScope, completed:((DirectionalSyncSummary) -> Void)) {
        
    }
    
    func pushLocalChanges(_ previousResult:SyncStepResult, completion:SyncStepCompletion) {
        
        
        
//        let scopes: [CKDatabaseScope] = [.public, .shared, .private]
//        
//        let unpushedChanges = Mist.localCachedRecordChangesStorage.modifiedRecordsAwaitingPushToCloud
//        let unpushedDeletions = Mist.localCachedRecordChangesStorage.deletedRecordsAwaitingPushToCloud
//        
//        var unpushedChangesDictionary: [CKDatabaseScope : [CKRecord]] = [:]
//        var idsOfUnpushedDeletionsDictionary: [CKDatabaseScope : [CKRecordID]] = [:]
//        
//        // Gather up all the unpushed changes and deletions and group them by database scope
//        var counter = 0
//        while counter < scopes.count {
//            
//            let scope = scopes[counter]
//            
//            let unpushedChangesForCurrentScope = unpushedChanges.filter({ $0.scope == scope }).map({ $0.backingRemoteRecord })
//            unpushedChangesDictionary[scope] = unpushedChangesForCurrentScope
//            
//            let idsOfUnpushedDeletionsForCurrentScope = unpushedDeletions.filter({ $0.scope == scope }).map({ CKRecordID(recordName: $0.identifier) })
//            idsOfUnpushedDeletionsDictionary[scope] = idsOfUnpushedDeletionsForCurrentScope
//            
//            counter = counter + 1
//            
//        }
//        
//        var modifyOperations: [CKDatabaseScope : CKModifyRecordsOperation] = [:]
//        var finishedStates: [CKDatabaseScope : Bool] = [
//            
//            .public : false,
//            .shared : false,
//            .private : false
//            
//        ]
//        
//        // Create a modify operation for each database scope
//        for scope in scopes {
//            
//            let recordsToSave = unpushedChangesDictionary[scope]
//            let recordIdsToDelete = idsOfUnpushedDeletionsDictionary[scope]
//            
//            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIdsToDelete)
//            modifyOperation.modifyRecordsCompletionBlock = { (savedRecords, recordIDsOfDeletedRecords, operationError) in
//                
//                // Mark this database's modify operation as complete
//                finishedStates[scope] = true
//                
//                // If there's an error, then return it and bail out of everything
//                // (since the operations have a linear dependency, bailing out of
//                // a particular operation bails out of any that follow)
//                if let operationError = operationError {
//                    completion(finishedStates, false, operationError)
//                    return
//                }
//                
//                // If this is the last of the three operations
//                if scope == .private {
//                    completion(finishedStates, true, nil)
//                }
//                
//            }
//            
//        }
//        
//        func dictionaryKeysMismatchFatalError(_ name:String, dictionary:[CKDatabaseScope:Any]) -> Never {
//            
//            fatalError(
//                "The keys for the \(name) dictionary and the scopes dictionary must match, " +
//                    "but they don't. Here are those dictionaries:\n" +
//                    "\(name): \(dictionary)\n" +
//                    "scopes: \(scopes)\n"
//            )
//            
//        }
//        
//        // Make each modify operation dependent upon the previous database scope
//        counter = (scopes.count - 1)
//        while counter > 0 {
//            
//            let currentScope = scopes[counter]
//            guard let currentModifyOperation = modifyOperations[currentScope] else {
//                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
//            }
//            
//            let previousScope = scopes[counter - 1]
//            guard let previousModifyOperation = modifyOperations[previousScope] else {
//                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
//            }
//            
//            currentModifyOperation.addDependency(previousModifyOperation)
//            
//            counter = counter - 1
//            
//        }
//        
//        let databases: [CKDatabaseScope : CKDatabase] = [
//            
//            .public : self.container.publicCloudDatabase,
//            .shared : self.container.sharedCloudDatabase,
//            .private : self.container.privateCloudDatabase
//            
//        ]
//        
//        // Add each modify operation to its respective database's operation queue
//        for scope in scopes {
//            
//            guard let database = databases[scope] else {
//                dictionaryKeysMismatchFatalError("databases", dictionary: databases)
//            }
//            
//            guard let modifyOperation = modifyOperations[scope] else {
//                dictionaryKeysMismatchFatalError("modifyOperations", dictionary: modifyOperations)
//            }
//            
//            database.add(modifyOperation)
//            
//        }
        
        
    }
    
}


