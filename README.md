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

## Usage

As stated in the repo description, Mist supports local persistence, typed models with true relationships, & automatic synchronization. Each is explained further below.

### Local Persistence

#### Storing Data

In order to understand the rationale for Mist's approach to data storage, let's remind ourselves of how CloudKit stores things.

##### How CloudKit Stores Data

As described in the [CloudKit documentation](https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/Introduction/Introduction.html), every CloudKit-enabled application has exactly one CloudKit Container (`CKContainer`), and every Container has exactly one Public Database (`CKDatabase`), N Private Databases, and N Shared Databases, where N is the number of User Records (`CKRecord`) in the Container. 

*(Graphic Goes Here)*

Therefore, all Users share the same Public Database, but each User has her own Private Database and her own Shared Database.

##### How Mist Stores Data

*(Graphic Goes Here)*

Mist represents this single-User view of the Container via its local cache. The local cache contains one Public Storage Scope, one Private Storage Scope, and one Shared Storage Scope, all of which are tied to the currently authenticated User.

#### Interacting with Data

##### How CloudKit Does Data Interaction

CloudKit requires you to perform operations (`CKOperation`) on the Database that's of interest to you. For instance, to find all the Todos that are not yet completed, you would do the following:

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

Let's break down what we're doing above:

1. We get a pointer to the database on which we want to operate
2. We create variables to hold the records we receive and the query cursor we might get
3. We create a predicate that describes the "uncompleted" status of the Todos.
4. We create a query that says we want to perform that predicate on the `Todo` type.
5. We perform a query operation (`CKQueryOperation`, subclass of `CKOperation`) against our database and as part of that we:
	1. Check for errors and potentially recursively call the query if we didn't get all the results the first time, and
	2. Add each Record we receive to our `todosINeedToDo` array.
6. We print the Todos that we received from CloudKit.
	
##### How Mist Does Data Interaction

By contrast, Mist is much simpler. It keeps the concept of indicating where you want to perform the search (the equivalent of performing the operation on the Public Database in the CloudKit example above), but greatly improves on the amount of boilerplate required:

```swift

Mist.find(recordsOfType: Todo, where: "completed = false", within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

Mist even provides a convenience functions on subclasses of `Record` so you can skip the `recordsOfType` parameter:

```swift

Todo.find(where: "completed = false", within: .public) { (recordOperationResult, todosIHaveToDo) in
    
    guard recordOperationResult.succeeded == true else {
        fatalError("Find operation failed due to error: \(recordOperation.error)")
    }
    
    print("Here are the Todos you still have to do: \(todosIHaveToDo)")
    
}

```

Mist operates on instances of concrete subclasses of its abstract class `Record`. 

To use Mist, start by creating subclasses of `Record` for each Record Type in your app's CloudKit schema.

### Creating a Record Subclass

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

Once you've created your `Record` subclasses, you can use them.

### Using a Record Subclass

```swift

let todo = Todo()

todo.title = "Take out the garbage"
todo.

```

## Advanced Usage

## Open Radars

## License
Mist is released under the MIT license. See LICENSE for details.
