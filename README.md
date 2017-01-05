# Mist

Mist is a lightweight adapter for CloudKit that supports local persistence, typed models with true relationships, & automatic synchronization.

*(TOC Goes Here)*

## Requirements
- iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+
- Xcode 8.1+
- Swift 3.0+

## Communication
- If you **found a bug**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **have a feature request**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **want to contribute**, [submit a pull request](https://github.com/mmccroskey/Mist/pulls/new).

## Installation

Before installing and using Mist, ensure that your application is configured to use CloudKit by following [Apple's QuickStart instructions](https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html#//apple_ref/doc/uid/TP40014987-CH2-SW1). 

### Cocoapods
### Carthage
### Manually
#### Embedded Framework

## Quick Start

### Getting Set Up

After [installing Mist](https://github.com/mmccroskey/Mist/blob/master/README.md#installation), you'll need to create you `Record` subclasses.

#### Creating a Record Subclass

All Mist operations are performed on instances of concrete subclasses of its abstract class `Record`. To use Mist, start by creating subclasses of `Record` for each Record Type in your app's CloudKit schema.

```swift
import Mist

class Todo : Record {

    // MARK: - Initializers
    // All subclasses of Record must call Record's init, passing the subclass name	
    
    init() { super.init(className: "Todo") }
    
    
    // MARK: - Properties
    // All properties of Record subclasses must be computed, 
    // and must call propertyValue/setPropertyValue. This means that
    // the types of all properties must conform to the RecordValue protocol.
    
    var title: String? {
    
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
    	
    }
    
    var dueDate: Date? {
    
        get { return self.propertyValue(forKey: "dueDate") as? Date }
        set { self.setPropertyValue(newValue as? RecordValue, forKey: "dueDate") }
    	
    }
    
    // If you know a property will always have a value, then you can
    // set its initial value, make it non-optional, and force the casting
    // of the object returned by the get and provided in the set.
    var completed: Bool = false {
    
        get { return self.propertyValue(forKey: "completed") as! Bool }
        set { self.setPropertyValue(newValue as RecordValue, forKey: "completed") }
    
    }
    
    
    // MARK: - Relationships
    // Relationships are just like properties, except that you use relatedRecord
    // and setRelatedRecord rather than using propertyValue and setPropertyValue.
    // These relationship-specific functions ensure that CKReferences are created
    // and destroyed as needed behind the scenes. The types of all relationships
    // must be subclasses of Record.
	
    var attachment: Attachment? {
    
        get { return self.relatedRecord(forKey: "attachment") as? Attachment }
        set { self.setRelatedRecord(newValue, forKey: "attachment") }
    
    }
    
}

```

#### Using a Record Subclass

Once you've created your `Record` subclasses, you'll want to use them to create Record instances.

```swift

let takeOutGarbage = Todo()
takeOutGarbage.title = "Take out garbage"
takeOutGarbage.dueDate = Date(timeInterval: (60 * 60), since: Date()) // Due in an hour

let walkTheDog = Todo()
walkTheDog.title = "Walk the dog"
walkTheDog.dueDate = Date(timeInterval: (60 * 60 * 2), since: Date()) // Due in two hours

```

### Mist Operations

All Mist operations are performed against its local cache -- records are fetched from the local cache, and saves/deletes are performed on the local cache. Separately from these operations, Mist synchronizes its local cache with CloudKit.

By default, this synchronization is triggered manually whenever you call `Mist.sync()`. However, if you wish, you can [enable automatic synchronization](). If you do so, then every operation will trigger an equivalent partial sync -- fetching Records will cause Mist to pull the latest Records into the local cache before querying that cache for the Records you requested; adding Records will cause Mist to add them to the local cache as normal, and then to push those changes up to CloudKit immediately. Therefore, when automatic synchronization is enabled, you never need to call `Mist.sync()` yourself, although it's harmless to do so.

Every Mist operation is asynchronous; each operation has a completion closure that provides feedback on whether the operation was successful, and in the case of the `fetch` and `find` operations, the closure also provides the Records requested if any exist.

Putting all of the above together, you'll notice that every Mist operation's completion closure at least two objects. The first is a `RecordOperationResult`, which indicates whether the relevant operation against the local cache was successful, and if not, then what went wrong. The second is an optional `SyncSummary`; the summary is `nil` if automatic synchronization is disabled (the default); if automatic synchronization is enabled, then the summary indicates whether syncing succeeded, and if not, then what went wrong.

**All the examples below assume that automatic synchronization is enabled.**

#### Saving Records

You save Records by adding them to the appropriate `StorageScope` using Mist's static `add` function:

```swift

// Todos created as shown above
let takeOutGarbage = ...
let walkTheDog = ...

let todos: Set<Todo> = [takeOutGarbage, walkTheDog]

Mist.add(todos, to: .public) { (recordOperationResult, syncSummary) in

    // recordOperationResult indicates whether saving to the local cache worked
    guard recordOperationResult.succeeded == true else {
        fatalError("Local save failed due to error: \(recordOperationResult.error)")
    }
    
    // syncSummary indicates whether saving to CloudKit worked;
    // syncSummary is nil by default, but has a value 
    // if automatic synchronization is enabled
    if let syncSummary = syncSummary {
        guard syncSummary.succeeded == true else {
            fatalError("CloudKit sync failed: \(syncSummary)")
        }
    }
    
    print("Todos saved successfully")
    
}

```

You use the `add` function whether you're saving new Records, or saving edits to existing Records.

#### Fetching Records

You fetch Records using Mist's static `fetch` operation, providing the `RecordID`s of the Records you wish to fetch, and the scope from which you wish to fetch them:

```swift

// Previously gathered RecordIDs
let idsOfRecordsToFetch = ...

Mist.fetch(recordsWithIDs: idsOfRecordsToFetch, from: .public) { (syncSummary, recordOperationResult, records) in 

    // syncSummary indicates whether fetching from CloudKit worked;
    // syncSummary is nil by default, but has a value 
    // if automatic synchronization is enabled
    if let syncSummary = syncSummary {
        guard syncSummary.succeeded == true else {
            fatalError("CloudKit sync failed: \(syncSummary)")
        }
    }

    // recordOperationResult indicates whether fetching from the local cache worked
    guard recordOperationResult.succeeded == true else {
        fatalError("Local save failed due to error: \(recordOperationResult.error)")
    }
    
    print("Here are the Records you requested: \(records")

}

```

#### Finding Records

Sometimes you don't have RecordIDs, but you still need to access Records that match certain criteria. You find Records using Mist's static `find` function:

```swift

Mist.find(recordsOfType: Todo, where: "completed = false", within: .public) { (syncSummary, recordOperationResult, todosIHaveToDo) in
    
    // syncSummary indicates whether fetching from CloudKit worked;
    // syncSummary is nil by default, but has a value 
    // if automatic synchronization is enabled
    if let syncSummary = syncSummary {
        guard syncSummary.succeeded == true else {
            fatalError("CloudKit sync failed: \(syncSummary)")
        }
    }

    // recordOperationResult indicates whether fetching from the local cache worked
    guard recordOperationResult.succeeded == true else {
        fatalError("Local save failed due to error: \(recordOperationResult.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

Mist also provides a convenience version of the `find` function on `Record`, so you can do the following with Record subclasses:

```swift

Todo.find(where: "completed = false", within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    // syncSummary indicates whether fetching from CloudKit worked;
    // syncSummary is nil by default, but has a value 
    // if automatic synchronization is enabled
    if let syncSummary = syncSummary {
        guard syncSummary.succeeded == true else {
            fatalError("CloudKit sync failed: \(syncSummary)")
        }
    }

    // recordOperationResult indicates whether fetching from the local cache worked
    guard recordOperationResult.succeeded == true else {
        fatalError("Local save failed due to error: \(recordOperationResult.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

#### Deleting Records

You delete Records by removing them from the appropriate `StorageScope` using Mist's static `remove` function:

```swift

// Todos created as shown above
let takeOutGarbage = ...
let walkTheDog = ...

let todos: Set<Todo> = [takeOutGarbage, walkTheDog]

Mist.remove(todos, from: .public) { (recordOperationResult, syncSummary) in

    // recordOperationResult indicates whether saving to the local cache worked
    guard recordOperationResult.succeeded == true else {
        fatalError("Local remove failed due to error: \(recordOperationResult.error)")
    }
    
    // syncSummary indicates whether saving to CloudKit worked;
    // syncSummary is nil by default, but has a value 
    // if automatic synchronization is enabled
    if let syncSummary = syncSummary {
        guard syncSummary.succeeded == true else {
            fatalError("CloudKit sync failed: \(syncSummary)")
        }
    }
    
    print("Todos deleted successfully")
    
}

```

## How It Works

As stated in the repo description, Mist supports **local persistence**, **typed models with true relationships**, & **automatic synchronization**. Each is explained further below.

### Local Persistence

#### Storing Data

In order to understand the rationale for Mist's approach to data storage, let's remind ourselves of how CloudKit stores things.

##### How CloudKit Stores Data

As described in the [CloudKit documentation](https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/Introduction/Introduction.html), every CloudKit-enabled application has exactly one CloudKit Container (`CKContainer`), and every Container has exactly one Public Database (`CKDatabase`), N Private Databases, and N Shared Databases, where N is the number of User Records (`CKRecord`) in the Container. 

*(Graphic Goes Here)*

Therefore, all Users share the same Public Database, but each User has her own Private Database and her own Shared Database.

##### How Mist Stores Data

*(Graphic Goes Here)*

Because a given device can only have one authenticated User at a time, Mist represents this single-User view of the Container via its local cache. The local cache contains one Public Storage Scope, one Private Storage Scope, and one Shared Storage Scope, all of which are tied to the currently authenticated User.

#### Interacting with Data

When using CloudKit directly, you interact with the data like so:

1. Create an Operation (`CKOperation`) that describes the action you want to perform (searching for records, creating/modifying records, or deleting records), 
2. Set up asynchronous callback closures that handle the results of the operation, and
3. Add the operation to the Database on which you want the action to be performed. 

This results in a large amount of fairly repetitive, verbose, and error-prone code, especially since many of the Operations require other ancillary objects (`CKQuery`s for queries, for example).

With Mist, interacting with data is simpler:

1. Call the relevant static function (`Mist.find`, `Mist.add`, or `Mist.remove`), 
2. Provide the relevant parameter (what you want to find, or the Records you want to create/modify/delete
3. Specify where you want to find it (the `StorageScope` (`.public`, `.private`, or `.shared`)).

All of this is done in a single line as parameters to the static function, and all results are handled in a single callback block.

Here are some compare-and-contrast examples.

##### Creating some new Todos & Saving Them

###### CloudKit

```swift

let takeOutGarbageID = CKRecordID(recordName: UUID().uuidString)
let takeOutGarbage = CKRecord(recordType: "Todo", recordID: takeOutGarbageID)
takeOutGarbage["title"] = NSString(string: "Take out garbage")
takeOutGarbage["dueDate"] = NSDate(timeInterval: (60 * 60), since: Date()) // Due in one hour

let walkTheDogID = CKRecordID(recordName: UUID().uuidString)
let walkTheDog = CKRecord(recordType: "Todo", recordID: walkTheDogID)
walkTheDog["title"] = NSString(string: "Walk the dog")
walkTheDog["dueDate"] = NSDate(timeInterval: (60 * 60 * 2), since: Date()) // Due in two hours

let container = CKContainer.default()
let publicDb = container.publicCloudDatabase

let modifyRecordsOp = CKModifyRecordsOperation(recordsToSave: [takeOutGarbage, walkTheDog], recordIDsToDelete: nil)
modifyRecordsOp.modifyRecordsCompletionBlock = { (modifiedRecords, deletedRecordIDs, error) in
    
    guard error == nil else {
        fatalError("An error occurred while saving the Todo: \(error)")
    }
    
    print("Todos saved successfully")
    
}

publicDb.add(modifyRecordsOp)

```

###### Mist

```swift

let takeOutGarbage = Todo()
takeOutGarbage.title = "Take out garbage"
takeOutGarbage.dueDate = Date(timeInterval: (60 * 60), since: Date()) // Due in one hour

let walkTheDog = Todo()
walkTheDog.title = "Walk the dog"
walkTheDog.dueDate = Date(timeInterval: (60 * 60 * 2), since: Date()) // Due in two hours

let todos: Set<Todo> = [takeOutGarbage, walkTheDog]

Mist.add(todos, to: .public) { (result, syncSummary) in

    guard result.succeeded == true else {
        fatalError("Local save failed due to error: \(result.error)")
    }
    
    guard syncSummary.succeeded == true else {
        fatalError("CloudKit sync failed: \(syncSummary)")
    }
    
    print("Todos saved successfully")
    
}

```

##### Deleting some existing Todos

###### CloudKit

```swift

// Fetch existing Todos
let takeOutGarbage = ...
let walkTheDog = ...

let recordIDsToDelete = [takeOutGarbage.recordID, walkTheDog.recordID]

let container = CKContainer.default()
let publicDb = container.publicCloudDatabase

let modifyRecordsOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
modifyRecordsOp.modifyRecordsCompletionBlock = { (modifiedRecords, deletedRecordIDs, error) in
    
    guard error == nil else {
        fatalError("An error occurred while saving the Todo: \(error)")
    }
    
    print("Todos deleted successfully")
    
}

publicDb.add(modifyRecordsOp)

```

###### Mist

```swift

// Fetch existing Todos
let takeOutGarbage = ...
let walkTheDog = ...

let todos: Set<Todo> = [takeOutGarbage, walkTheDog]

Mist.remove(todos, from: .public) { (result, syncSummary) in

    guard result.succeeded == true else {
        fatalError("Local save failed due to error: \(result.error)")
    }
    
    guard syncSummary.succeeded == true else {
        fatalError("CloudKit sync failed: \(syncSummary)")
    }
    
    print("Todos deleted successfully")
    
}

```

##### Fetching Todos You Haven't Yet Completed

###### CloudKit

```swift

 let container = CKContainer.default()
 let publicDb = container.publicCloudDatabase
 
 var todosINeedToDo: Set<CKRecord> = []
 var queryCursor: CKQueryCursor? = nil
 
 let queryPredicate = NSPredicate(format: "completed = false")
 let query = CKQuery(recordType: "Todo", predicate: queryPredicate)
 
 func performQuery() {
     
     let queryOperation = CKQueryOperation(query: query)
     queryOperation.cursor = queryCursor
     queryOperation.recordFetchedBlock = { todosINeedToDo.insert($0) }
     queryOperation.queryCompletionBlock = { (cursor, error) in
         
         guard error == nil else {
             fatalError("Error while querying CloudKit: \(error)")
         }
         
         if let cursor = cursor {
             
             queryCursor = cursor
             performQuery()
             
         } else {
             
             print("Here are the todos you still need to complete: \(todosINeedToDo)")
             
         }
         
     }
     
     publicDb.add(queryOperation)
     
 }
 
 performQuery()

```
	
###### Mist

```swift

Mist.find(recordsOfType: Todo, where: "completed = false", within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

Or even simpler:

```swift

Todo.find(where: "completed = false", within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

## Advanced Usage

## Open Radars

## License
Mist is released under the MIT license. See LICENSE for details.
