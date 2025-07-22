import Foundation
import PlaygroundSupport

/**
 Actor
 */

// 🤔 MARK: Not using Actor

class User1 {
    let id: String
    let name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

class UserStorage1 {
    private var store = [String: User1]()
    private let queue = DispatchQueue(label: "user.save.queue")
    
    func get(_ id: String) -> User1? {
        queue.sync {
            return store[id]
        }
    }
    
    func save(_ user: User1) {
        queue.sync {
            self.store[user.id] = user
        }
    }
}

let storage1 = UserStorage1()
let user1 = User1(id: "1", name: "Alice")
storage1.save(user1)
print("not using actor:", storage1.get("1")?.name ?? "-")


// 🥳 MARK: Using Actor (which works as exactly the same with above)

final class User2: Sendable {
    let id: String
    let name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

actor UserStorage2 {
    private var store = [String: User2]()
    
    func get(_ id: String) -> User2? {
        store[id]
    }
    
    func save(_ user: User2) {
        store[user.id] = user
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true
Task {
    let storage2 = UserStorage2()
    let user2 = User2(id: "3", name: "Bear")
    await storage2.save(user2)
    print("using actor:", await storage2.get("3")?.name ?? "-")
    
    PlaygroundPage.current.finishExecution()
}
