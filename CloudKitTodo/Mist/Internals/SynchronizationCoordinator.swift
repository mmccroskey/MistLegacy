//
//  SynchronizationCoordinator.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/5/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

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

internal class SynchronizationCoordinator {
    
    private let remoteDataCoordinator = RemoteDataCoordinator()
    
    func refreshUser(_ completion:((Bool) -> Void)) {
        
        let remote = self.remoteDataCoordinator
        remote.confirmICloudAvailable { (result) in
            remote.confirmUserAuthenticated(result, completion: { (result) in
                remote.confirmUserRecordExists(result, completion: { (result) in
                    completion(result.success)
                })
            })
        }
        
    }
    
    func sync(_ qOS:QualityOfService?=QualityOfService.default, finished:((SyncSummary) -> Void)?=nil) {
        
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
    
}
