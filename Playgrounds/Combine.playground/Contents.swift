//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport
import Combine

PlaygroundPage.current.needsIndefiniteExecution = true

// MARK: - Combine Zip, flatMap

var cancellableBag = Set<AnyCancellable>()

func createPublisher(_ prefix: String, _ number: Int = .random(in: 0...10)) -> AnyPublisher<Int, Error> {
    print(prefix, "start", number)
    
    return Future() { promise in
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(abs(number))) {
            print(prefix, "finish", number)
            if number >= 0 {
                promise(Result.success(number))
            } else {
                promise(Result.failure(NSError()))
            }
        }
    }
    .eraseToAnyPublisher()
}

func testFlatMap() {
    createPublisher(#function, 2)
        .flatMap({ _ in createPublisher(#function, 4) })
        .flatMap({ _ in createPublisher(#function, 6) })
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("\(#function) error: \(error)")
            }
        }, receiveValue: { value in
            print("\(#function) value: \(value)")
        })
        .store(in: &cancellableBag)
}

func testZip() {
    Publishers.Zip3(createPublisher(#function), createPublisher(#function), createPublisher(#function))
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("\(#function) error: \(error)")
            }
        }, receiveValue: { value in
            print("\(#function) value: \(value)")
        })
        .store(in: &cancellableBag)
}

func testZipAndFlatMap() {
    Publishers.Zip(createPublisher(#function, 5), createPublisher(#function, 1))
        .flatMap({ _ in createPublisher(#function, 3) })
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("\(#function) error: \(error)")
            }
        }, receiveValue: { value in
            print("\(#function) value: \(value)")
        })
        .store(in: &cancellableBag)
}

// -------------------------------------

/*
// start 2 > finish 2 > start 4 > finish 4 > start 6 > finish 6
// >> testFlatMap value: 6 (= the last value)
testFlatMap()
// start 1, 2, 3 > finish 1 > finish 2 > finish 3
// >> testZip value: (1, 2, 3)
testZip()
// start 5, 1 > finish 1 > finish 5 > start 3 > finish 3
// >> testFlatMap value: 6
testZipAndFlatMap()
*/

// MARK: - Custom Publisher & Subscription & Subscriber

struct TestPublisher<Output: Equatable>: Publisher {
    typealias Failure = Error
    
    func receive<S>(subscriber: S) where S : Subscriber, any Failure == S.Failure, Output == S.Input {
        Swift.print("Publisher receive subscriber -", subscriber)
        let subscription = TestSubscription<S, Output>(subscriber)
        subscriber.receive(subscription: subscription)
    }
}

class TestSubscription<S: Subscriber, Output: Equatable>: Subscription where S.Input == Output, S.Failure == Error {
    var combineIdentifier: CombineIdentifier = .init()
    
    var subscriber: S?
    
    init(_ subscriber: S) {
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        print("Subscription request demand -", demand)
        if demand > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let output = "1 sec passed" as? Output {
                    self.subscriber?.receive(output)
                    self.subscriber?.receive(completion: .finished)
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: nil)
                    self.subscriber?.receive(completion: .failure(error))
                }
                self.cancel()
            }
        }
    }
    
    func cancel() {
        print("Subscription cancel")
        subscriber = nil
    }
}

struct TestSubscriber<Input: Equatable>: Subscriber {
    typealias Failure = Error
    
    var combineIdentifier: CombineIdentifier = .init()
    
    func receive(subscription: any Subscription) {
        print("Subscriber receive subscription -", subscription)
        subscription.request(.unlimited)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        print("Subscriber receive input -", input)
        return .none
    }
    
    func receive(completion: Subscribers.Completion<any Failure>) {
        print("Subscriber receive completion -", completion)
    }
}

// -------------------------------------

/*
let publisher = TestPublisher<String>()
let subscriber = TestSubscriber<String>()

publisher.receive(subscriber: subscriber)
*/
