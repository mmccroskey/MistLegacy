# Mist

Mist is an adapter for CloudKit that supports local persistence, typed models with true relationships, automatic synchronization, and a convention-over-configuration approach to enforcing best practices.

*(TOC Goes Here)*

---

## Why Mist?

Mist was created because **CloudKit is great, but it has some fundamental shortcomings**:

* Although it lets you sync records between cloud and device, it doesn't let you save them locally once they've arrived;
* Although it has a flexible approach to data modelling, that flexibility makes it verbose and error-prone to use;
* Although it has incredible features for synchronization, they're arcane & opt-in rather than obvious & automatic.

Mist seeks to solve these problems by directly supporting **local persistence**, by requiring the use of **typed models with true relationships**, & by providing **automatic synchronization**. 

To start using Mist, jump to [Usage](https://github.com/mmccroskey/Mist/blob/master/README.md#usage), or to learn more about how Mist is implemented, see [Mist's Architecture Explained](https://github.com/mmccroskey/Mist/blob/master/README.md#mists-architecture-explained).

## Requirements
- iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+
- Xcode 8.1+
- Swift 3.0+

## Communication
- If you have **found a bug**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **have a feature request**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **want to contribute**, [submit a pull request](https://github.com/mmccroskey/Mist/pulls/new).

## Installation

Before installing and using Mist, ensure that your application is configured to use CloudKit by following [Apple's QuickStart instructions](https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html#//apple_ref/doc/uid/TP40014987-CH2-SW1). 

### Cocoapods
### Carthage
### Manually
#### Embedded Framework

---

## Usage

### Getting Set Up

After [installing Mist](https://github.com/mmccroskey/Mist/blob/master/README.md#installation), you'll need to create your `Record` subclasses.

#### Creating Record Subclasses

All Mist operations are performed on instances of concrete subclasses of its abstract class `Record`. To use Mist, start by creating subclasses of `Record` for each Record Type in your app's CloudKit schema.

Because every CloudKit Container has a `Users` Record Type, Mist defines a subclass for it out of the box:

```swift

class CloudKitUser : Record {
    
    
    // MARK: - Initializers
    // All subclasses of Record must call Record's init, 
    // passing the name of the CloudKit Record Type they represent
    
    init() { super.init(className: "Users") }
    
}

```

If you wish to add any properties to Users, then you should create a subclass of `CloudKitUser`:

```swift

class User : CloudKitUser {
    
    
    // MARK: - Properties
    // All properties of Record subclasses must be computed, 
    // and must call propertyValue/setPropertyValue. This means that
    // the types of all properties must conform to the RecordValue protocol.
    
    var firstName: String? {
    
        get { return self.propertyValue(forKey: "firstName") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"firstName") }
    	
    }
    
    var lastName: String? {
    
        get { return self.propertyValue(forKey: "lastName") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"lastName") }
    	
    }
    
}

```

Now let's create custom Record subclasses that match our app's schema:

```swift
import Mist

class Todo : Record {
    
    
    // MARK: - Initializers
    
    init() { super.init(className: "Todos") }
    
    
    // MARK: - Properties
    
    var title: String? {
    
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
    	
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
    
    var assignee: User? {
    
        get { return self.relatedRecord(forKey: "assignee") as? User }
        set { self.setRelatedRecord(newValue, forKey: "assignee") }
    
    }
    
    // Record has a parent property that's a real-relationship equivalent
    // of CKRecord's parent CKReference property. You can use Record's parent
    // directly in your code, or can wrap it in a custom property name 
    // for convenience as we've done here.
    var todoList: TodoList? {
    
        get { return self.parent as? TodoList }
        set { self.parent = newValue }
    
    }
    
}


class TodoList : Record {
    
    
    // MARK: - Initializers
    
    init() { super.init(className: "TodoLists") }
    
    
    // MARK: - Properties
    
    var title: String? {
    
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
    	
    }
    
    
    // MARK: - Relationships
    
    // Record has a read-only children property that automatically holds 
    // all the Records that have this Record as their parent. You can 
    // use Record's children property directly in your code, or you can
    // wrap it in a custom property name for convenience as we've done here.
    var todos: Set<Todo>? {
        get { return self.children as? Set<Todo> }
    }
    
}


class Attachment : Record {
    
    
    // MARK: - Initializers
    
    init() { super.init(className: "Attachments") }
    
    
    // MARK: - Properties
    
    var title: String? {
    
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
    	
    }
    
    
    // MARK: - Assets
    // Mist has an Asset class that's equivalent to CloudKit's CKAsset, except that
    // Mist automatically persists the assets locally so they're always available.
    
    var attachedFile: Asset? {
        
        get { return self.asset(forKey: "attachedFile") }
        set { self.setAsset(forKey: "attachedFile") }
	
    }
    
}

```

#### Using Record Subclasses

Once you've created your `Record` subclasses, you'll want to use them to create Record instances. Let's say you're going to do some chores around the house, while you send out your husband to run some errands:

```swift

// Mist has a convenience property for the current User;
// it's nil if no User is logged into iCloud on the device.
// See Authentication section of README for details.
guard let me = Mist.currentUser else {
    
    print("ERROR: We're not authenticated, so we can't assign todos to ourself.")
    return
    
}

let chores = TodoList()
chores.title = "Chores"

let takeOutGarbage = Todo()
takeOutGarbage.title = "Take out garbage"
takeOutGarbage.todoList = chores
takeOutGarbage.assignee = me

let walkTheDog = Todo()
walkTheDog.title = "Walk the dog"
walkTheDog.todoList = chores
walkTheDog.assignee = me


let hubby = User()
hubby.firstName = "David"
hubby.lastName = "Allen"

let errands = TodoList()
errands.title = "Errands"

let groceryListTextFile = Asset()
groceryListTextFile.fileURL = ... // URL to local file on device

let groceryList = Attachment()
groceryList.title = "Grocery List"
groceryList.asset = groceryListTextFile

let buyGroceries = Todo()
buyGroceries.title = "Buy groceries"
buyGroceries.todoList = errands
buyGroceries.assignee = hubby
buyGroceries.attachment = groceryList

let pickUpDryCleaning = Todo()
pickUpDryCleaning.title = "Pick up dry cleaning"
pickUpDryCleaning.todoList = errands
pickUpDryCleaning.assignee = hubby

```

Now we just need to save these Records. Before we do that, though, we need to learn a bit about Mist's Operations, since they're the basis of saving Records, and of all other Record actions.

### Mist Operations

All Mist operations are performed against its local cache -- records are fetched from the local cache, and saves/deletes are performed on the local cache. Separately from these operations, Mist synchronizes its local cache with CloudKit.

By default, this synchronization is triggered manually whenever you call `Mist.sync()`. However, if you wish, you can [enable automatic synchronization](). If you do so, then every operation will trigger an equivalent partial sync -- fetching Records will cause Mist to pull the latest Records into the local cache before querying that cache for the Records you requested; adding Records will cause Mist to add them to the local cache as normal, and then to push those changes up to CloudKit immediately. Therefore, when automatic synchronization is enabled, you never need to call `Mist.sync()` yourself, although it's harmless to do so.

Every Mist operation is asynchronous; each operation has a completion closure that provides feedback on whether the operation was successful, and in the case of the `fetch` and `find` operations, the closure also provides the Records requested if any exist.

Putting all of the above together, you'll notice in the code below that every Mist operation's completion closure has at least two objects. The first is a `RecordOperationResult`, which indicates whether the relevant operation against the local cache was successful, and if not, then what went wrong. The second is an optional `SyncSummary`; the summary is `nil` if automatic synchronization is disabled (the default); if automatic synchronization is enabled, then the summary indicates whether syncing succeeded, and if not, then what went wrong.

**All the examples below assume that automatic synchronization is enabled.**

#### Saving Records

You save Records by adding them to the appropriate `StorageScope` using Mist's static `add` function:

```swift

// TodoLists created as shown above
let chores = ...
let errands = ...

let todoLists: Set<TodoList> = [chores, errands]

Mist.add(todoLists, to: .public) { (recordOperationResult, syncSummary) in

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
    
    print("TodoLists and their dependent objects saved successfully")
    
}

```

You use the `add` function whether you're saving new Records, or saving edits to existing Records.

A quick side note: by default, saving a Record saves all the Records linked to it -- that is, the Records with which it has relationships. Therefore, saving the TodoLists in the example above saves all the Todos we created, as well the new User (your husband) and even the Attachment we added to our "Buy groceries" Todo. This default behavior can be overridden via an optional property on the `add` function; see [Advanced Usage](https://github.com/mmccroskey/Mist/blob/master/README.md#advanced-usage) for more info.

#### Fetching Records

You fetch Records using Mist's static `fetch` operation, providing the `RecordID`s of the Records you wish to fetch, and the scope from which you wish to fetch them. Let's say some time has passed and you want to check on your husband's progress to see if he's completed either of his Todos:

```swift

let idsOfHubbysTodos: Set<RecordID> = [buyGroceries.recordID, pickUpDryCleaning.recordID]

Mist.fetch(recordsWithIDs: idsOfHubbysTodos, from: .public) { (syncSummary, recordOperationResult, records) in 

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
        fatalError("Local fetch failed due to error: \(recordOperationResult.error)")
    }
    
    let buyGroceries = records.filter({ $0.title == "Buy Groceries" }).first
    let pickUpDryCleaning = records.filter({ $0.title == "Pick up dry cleaning" }).first
    guard let buyGroceries = buyGroceries, let pickUpDryCleaning = pickUpDryCleaning else {
        
        print("Some of your husband's Todos no longer exist! I wonder if he deleted them?")
        return
        
    }
    
    if buyGroceries.completed == true && pickUpDryCleaning.completed == true {
        print("Your husband's done with both tasks!")
    } else if buyGroceries.completed == true || pickUpDryCleaning.completed == true {
        print("Your husband's still got work to do...")
    } else {
        print("Hubby seems to have gotten sidetracked.")
    }

}

```

#### Finding Records

Sometimes you don't have RecordIDs, but you still need to access Records that match certain criteria. You find Records using Mist's static `find` function:

```swift

Mist.find(recordsOfType: Todo, where: { $0.completed == false }, within: .public) { (syncSummary, recordOperationResult, todosStillToDo) in
    
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
    
    print("Here are the Todos you & your husband still have to do: \(todosStillToDo)")
    
}

```

Mist also provides a convenience version of the `find` function on `Record`, so you can do the following with Record subclasses:

```swift

Todo.find(where: { $0.completed == false && $0.assignmee == me }, within: .public) { (recordOperationResult, todosINeedToDo) in
    
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
    
    print("Here are the Todos you still have to do: \(todosINeedToDo)")
    
}

```

If you prefer, you can also use `find` with an `NSPredicate` rather than a closure:

```swift

let iAmTheAssigneeAndTodoNotCompleted = NSPredicate(format: "assignee == %@ && completed == false", argumentArray: [me])
Todo.find(where: iAmTheAssigneeAndTodoNotCompleted, within: .public) { (recordOperationresult, records) in
    
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
    
    print("Here are the Todos you still have to do: \(todosINeedToDo)")
    
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

When deleting a Record, deletes may or may not cascade to related Records. Just like with CloudKit's `CKReference`s, each relationship you create has a corresponding `RelationshipAction` -- either `deleteSelf` or `none` -- which is equivalent to `CKReference`'s `CKReferenceAction`.

### Configuration

Configuration info goes here.

### Callbacks

Callbacks info goes here.

---

### Advanced Usage

Advanced usage info goes here.

---

### Mist's Architecture Explained

### Local Persistence

#### Storing Data

In order to understand the rationale for Mist's approach to data storage, let's remind ourselves of how CloudKit stores things.

##### How CloudKit Stores Data

As described in the [CloudKit documentation](https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/Introduction/Introduction.html), every CloudKit-enabled application typically has one CloudKit Container (`CKContainer`), and every Container has exactly one Public Database (`CKDatabase`), N Private Databases, and N Shared Databases, where N is the number of User Records (`CKRecord`) in the Container. 

*(Graphic Goes Here)*

Therefore, all Users share the same Public Database, but each User has her own Private Database and her own Shared Database. Anyone (whether or not she is authenticated) can read from the Public Database, but to read from the Private or Shared Databases or to write to any of the three Databases, the User must be authenticated.

##### How Mist Stores Data

*(Graphic Goes Here)*

Because a given device can only have one authenticated User at a time, Mist represents this single-User view of the Container via its local cache. The local cache contains one Public Storage Scope, one Private Storage Scope, and one Shared Storage Scope. The Public Storage Scope exists indpependently of whether a User is authenticated; the other two Scopes (Private and Shared) are tied to the currently authenticated User, meaning that each instance of Mist has U Private Scopes and U Shared Scopes, where U is the number of Users that have ever been authenticated on a particular Device. Mist allows you to interact with the Public Scope, and the Private and Shared Scopes for the current User if one exists.

#### Interacting with Data

When using CloudKit directly, you interact with the data like so:

1. Create an Operation (`CKOperation`) that describes the action you want to perform (searching for records, creating/modifying records, deleting records, etc.), 
2. Set up asynchronous callback closures that handle each result of the operation and then the completion of the operation, and
3. Add the operation to the Database on which you want the action to be performed. 

Mist takes a similar, but more compact and straightforward approach:

1. Call the relevant static function (`Mist.fetch`, `Mist.find`, `Mist.add`, or `Mist.remove`), 
2. Provide the relevant parameter (what you want to fetch/find, or the Records you want to create/modify/delete)
3. Specify where you want to find it (the `StorageScope` (`.public`, `.private`, or `.shared`)).

All of this is done in a single line as parameters to the static function, and all results are handled in a single callback block.

Here are some compare-and-contrast examples.

##### Creating some new Todos & Saving Them

###### CloudKit

```swift

let takeOutGarbageID = CKRecordID(recordName: UUID().uuidString)
let takeOutGarbage = CKRecord(recordType: "Todo", recordID: takeOutGarbageID)
takeOutGarbage["title"] = NSString(string: "Take out garbage") // CKRecordValue requires that we use NSString, not String

let walkTheDogID = CKRecordID(recordName: UUID().uuidString)
let walkTheDog = CKRecord(recordType: "Todo", recordID: walkTheDogID)
walkTheDog["title"] = NSString(string: "Walk the dog")

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
takeOutGarbage.title = "Take out garbage" // Mist allows us to use the String directly, not NSString like above

let walkTheDog = Todo()
walkTheDog.title = "Walk the dog"

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
 
 let queryPredicate = NSPredicate(format: "completed == false")
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

Mist.find(recordsOfType: Todo, where: { $0.completed == false }, within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

Or even simpler:

```swift

Todo.find(where: { $0.completed == false }, within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

### Typed Records with Real Relationships

#### The Problems CloudKit Creates

CloudKit is all about storing Records, so it's no surprise that `CKRecord` lies at the core of its implementation. Like CloudKit as a whole, `CKRecord` is intentionally designed to be flexible, and so it acts as a highly mutable container for content: `CKRecord`'s property names, its identifier (`CKRecordID`), and even its type (`recordType`) are all defined as or ultimately backed by Strings, and all properties of `CKRecord` are optional. While this certainly makes things flexible, it has a very significant downside -- it's all too easy to make careless typos when developing with `CKRecord`, and since these typos occur in raw Strings, they'll never be caught by the compiler and thus will likely result in subtle and hard-to-notice runtime errors. It also means that you may end up writing lots of code to ensure that certain properties always have a value, and that that value is of a certain Type, since CloudKit won't enforce that for you.

CloudKit also supports a just-in-time schema in development, meaning that you can create your app's schema simply by submitting objects to CloudKit that match it. Again, this makes things very flexible, but has the downside that a simple typo (e.g. listing a `CKRecord`'s `recordType` as `"Todos"` in one part of your code, but as `"Todo"` in another) can cause you to have a different schema than you intended, and leave you with data distributed in bizarre ways across your Container. And besides, most developers settle on a schema for the app quite early on in development, and then don't change it unless they're already making other major changes to their codebase (e.g. as part of making a major new version of their app).

Finally, while CloudKit allows you to relate objects to one another, they require that these relationships are represented by an intermediary object, the `CKReference`. This means that if you have a highly interrelated data model, you end up doing tons of CloudKit fetches to get an object, and then its related objects, and those objects' related objects, and so on.

#### The Solution Mist Provides

Mist seeks to solves all these problems through its abstract class `Record`, and through conventions about how it's used. `Record` wraps `CKRecord` (meaning it has a `CKRecord` instance as a private property), and enforces best practices around how to create and manipulate `CKRecord`s, as described below.

##### Structure and Conventions for Using `Record`

`CKRecord` is intended to be used directly, and cannot be subclassed. This means that you're forced to interact with every `CKRecord` instance using tons of raw Strings (for property name and `recordType` values) and to write tons of repetitive code to ensure that a certain property's value is of the type you expect, among other disadvantages.

By contrast, `Record` is an abstract class and therefore must be subclassed to be used. Every `Record` subclass follows a couple of simple conventions, and by following these conventions, you get all the advantages you would get with a traditional Swift class. Every `Record` subclass must:

1. Implement an `init` function that calls `Record`'s `init(recordTypeName:String)` function, and passes in the name of the Record Type from your CloudKit Container that this subclass represents
2. Implement all "raw" properties, relationships, and related Assets as computed properties, calling `Record`s respective backing functions within each property's `get` & `set` pseudo-functions

Here's the rationale for each of these rules.

###### The `init` function

By requiring that every subclass of `Record` call `Record`s `init` function and provide a `recordTypeName`, Mist removes the need to provide `typeName` every time you create a Record instance, while still allowing you to decouple the name of the subclass from the name of its respective Record Type in CloudKit. This is particularly useful if you want to follow the typical database vs. ORM convention where database tables (equivalent to Record Types) have plural names (`Users`, `Todos`, etc.), while ORM Models (equivalent to `Record` subclasses) have singular names (`User`, `Todo`, etc.). Whether you choose to follow this convention is up to you.

###### Using computed properties

By implementing "raw" properties, relationships, and Assets as computed properties, Mist allows you to get and set the values of your properties in a way that's ultimately compatible with the `CKRecord` that stores them, while also giving you all the advantages of a proper Swift property. In particular, these properties:

- Have names that Xcode can auto-complete, and can check for correctness at compile time
- Have types that Swift can enforce in both directions, so that you can only set values on that property that make sense, and so that you don't have to check the type of a property's value every time you want use it
- Have explicit nullability, so that if you know a particular property will always have a value (for instance, a boolean flag), you can set it up as such and then you never have to check to see whether it's nil

And in the case of relationships and Assets, you get additional advantages. With relationships, you're able to directly relate two `Record`s together (something you cannot do with `CKRecord`), and then when you fetch the parent Record, you'll get the related Record automatically without another fetch by default. With assets, you're able to access the asset immediately, since Mist guarantees that it remains cached on the device as long as its respective Record is locally cached.

##### Other Advantages of Using `Record`

##### Identifiers

CloudKit requires that the unique identifiers for `CKRecord`s (instances of `CKRecordID`) must be unique to each Record within a given Object Type. However, CloudKit does nothing to enforce this, since the `recordName` property of `CKRecordID` can be any String, and thus could be repeated across `CKRecord` instances.

By contrast, Mist's `Record` has an `id` property, which is an instance of `RecordID` (a typealias of `String`) and is read-only; at initialization time, it automatically gets set to a globally-unique value using `NSUUID`.

##### Record Zones

Although it's not very well documented, proper use of Record Zones is critical to enabling efficient synchronization of objects between CloudKit and the local device. In particular, custom record zones cannot be used at all in the public database, but they must be used in the private and shared databases in order to be able to get efficient change sets for CloudKit updates.

Mist and `Record` work together to ensure that these best practices are followed. In the Private and Shared scopes, root records (`Record` instances that have no `parent` Record) get their own Record Zone, and all the children coming off of that Record are put in that same Record Zone (an implicit requirement of CloudKit). In the public scope, everything is put in the default Record Zone (since CloudKit doesn't allow custom Record Zones in the Public Scope) and alternative approaches are used to get efficient data synchronization.

### Automatic Synchronization

Synchroniziation is typically a three-step process: pulling down records from the server, reconciling them with what's on the device, and pushing new records back up to the server. This reconciliation process can sometimes be complex, but Mist takes a simple approach:

1. Deletes win
2. Latest edit wins



---

## FAQs

FAQs go here.

## Open Radars

Open Radars go here.

## License
Mist is released under the MIT license. See LICENSE for details.
