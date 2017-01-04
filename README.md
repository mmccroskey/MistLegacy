# Mist

Mist is a lightweight adapter for CloudKit that supports local persistence, custom typed models, true relationships, & automatic synchronization.

*TOC Goes Here*

## Requirements
- iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+
- Xcode 8.1+
- Swift 3.0+

## Communication
- If you **found a bug**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **have a feature request**, [open an issue](https://github.com/mmccroskey/Mist/issues/new).
- If you **want to contribute**, [submit a pull request](https://github.com/mmccroskey/Mist/pulls/new).

## Installation
### Cocoapods
### Carthage
### Manually
#### Embedded Framework

## Usage

To use Mist, start by creating subclasses of `Record` for each Record Type in your app's CloudKit schema.

### Creating a Record Subclass
All Records in Mist must be instances of subclasses of `Record`:

```swift
import Mist

class Todo : Record {

    // MARK: - Initializers
    // All subclasses of Record must call Record's init, passing the class name	
    
    init() { super.init(className: "Todo") }
    
    
    // MARK: - Properties
    // All properties of Record subclasses must be computed, 
    // and must call propertyValue/setPropertyValue.
    
    var title: String? {
    
        get { return self.propertyValue(forKey: "title") as? String }
        set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
    	
    }
    
    var dueDate: Date? {
    
        get { return self.propertyValue(forKey: "dueDate") as? Date }
        set { self.setPropertyValue(newValue as? RecordValue, forKey: "dueDate") }
    	
    }
    
    // If you know a property will always have a value, then you can g
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
    // and destroyed as needed behind the scenes.
	
    var attachment: Attachment? {
    
        get { return self.relatedRecord(forKey: "attachment") as? Attachment }
	set { self.setRelatedRecord(newValue, forKey: "attachment") }
    
    }
    
}

```

## Advanced Usage

## Open Radars

## License
Mist is released under the MIT license. See LICENSE for details.
