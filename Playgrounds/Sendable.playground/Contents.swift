import Foundation

/**
 [Sendable] - https://developer.apple.com/documentation/swift/sendable
 
 Sendable means a kind of "safety mark".
 If something conforms to Sendable, it means it's thread-safe, and it means it has no problem whenever whichever threads tries to write to it.
 Instances of any Sendable can be used in any concurrency domain(closure, async-await).
 */

// 1. MARK: `Int` is already Sendable.

extension Int {}

// 2. MARK: No problem to conform to Sendable, because `struct` is value type and all the properties are already Sendable.

struct Sendable_Struct: Sendable {
    var int: Int
}

// 3. MARK: Let's try to add Sendable to `class`

// ❌ Non-final class 'Sendable_Class' cannot conform to 'Sendable'; use '@unchecked Sendable'
// 1️⃣ add `final`.
// 2️⃣ add `@unchecked Sendable`. it means "it dosen't need to be checked that it is really thread-safe. (not recommended)
/*
class Sendable_Class: Sendable {
    let int: Int = 123
}
*/

final class Sendable_Class: Sendable { // 1️⃣ add `final`.
    let int: Int = 123
}

// 💁🏻‍♀️ Here's some tips.
// `final` class means you can't make it as a super class of any class like below.
// And that's why non-final class can't be Sendable because it might add more properties which don't conform to Sendable.
/*
class Sendable_SubClass: Sendable_Class {}
*/

// 4. MARK: non-sendable property or case is not allowed

enum Sendable_Enum: Sendable {
    case one(number: Int)
    // ❌ Associated value 'two(value:)' of 'Sendable'-conforming enum 'Sendable_Enum' has non-sendable type '(value: NSAttributedString)'
    // case two(value: NSAttributedString)
}

// 5. MARK: When I should use @unchecked Sendable?

// ❌ Stored property 'name' of 'Sendable'-conforming class 'Company' is mutable
// It's because Company class has mutable property.
/*
final class Company: Sendable {
    private var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func update(_ newName: String) {
        self.name = newName
    }
}
 */

// 👉 add @unchecked Sendable, and make sure that it's thread-safe by yourself(using DispatchQueue sync).
final class Company: @unchecked Sendable {
    private var name: String
    
    private let queue = DispatchQueue(label: "company.update.queue")
    
    init(name: String) {
        self.name = name
    }
    
    func update(_ newName: String) {
        queue.sync {
            self.name = newName
        }
    }
}
