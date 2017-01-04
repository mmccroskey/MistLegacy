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

### Creating a Record
All Records in Mist must be instances of subclasses of `Record`:

```swift
import Mist

class Todo : Record {
	
	
	// MARK: - Initializers
	// All subclasses of Record must call Record's init, passing the class name	
	
	init() { super.init(className: "Todo") }
	
	
	// MARK: - Properties
	// All properties 
	
	var title: String? {
		
		get { return self.propertyValue(forKey: "title") as? String }
		set { self.setPropertyValue(newValue as? RecordValue, forKey:"title") }
		
	}
    
    var dueDate: Date? {
        
        get { return self.propertyValue(forKey: "dueDate") as? Date }
        set { self.setPropertyValue(newValue as? RecordValue, forKey: "dueDate") }
        
    }
    
}

```

## Advanced Usage

## Open Radars

## License
Mist is released under the MIT license. See LICENSE for details.
