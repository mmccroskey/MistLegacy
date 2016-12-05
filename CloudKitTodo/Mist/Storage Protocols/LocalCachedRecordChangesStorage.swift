//
//  LocalCachedRecordChangesStorage.swift
//  CloudKitTodo
//
//  Created by Matthew McCroskey on 12/1/16.
//  Copyright © 2016 Less But Better. All rights reserved.
//

import Foundation

protocol LocalCachedRecordChangesStorage {
    
    
    // MARK: - Caching Record Modifications
    
    var publicModifiedRecordsAwaitingPushToCloud: Set<Record> { get set }
    
    func userModifiedRecordsAwaitingPushToCloud(identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Set<Record>
    func addUserModifiedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope)
    func removeUserModifiedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope)
    
    
    
    // MARK: - Caching Record Deletions
    
    var publicDeletedRecordsAwaitingPushToCloud: Set<Record> { get set }
    func userDeletedRecordsAwaitingPushToCloud(identifiedBy userRecordIdentifier:RecordIdentifier, inScope scope:StorageScope) -> Set<Record>
    func addUserDeletedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, toScope scope:StorageScope)
    func removeUserDeletedRecordAwaitingPushToCloud(_ record:Record, identifiedBy userRecordIdentifier:RecordIdentifier, fromScope scope:StorageScope)
    
}
