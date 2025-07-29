//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport
import Combine

PlaygroundPage.current.needsIndefiniteExecution = true

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

/*
 start 2 > finish 2 > start 4 > finish 4 > start 6 > finish 6
 >> testFlatMap value: 6 (= the last value)
 */
testFlatMap()

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

/*
 start 1, 2, 3 > finish 1 > finish 2 > finish 3
 >> testZip value: (1, 2, 3)
 */
testZip()

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

/*
 start 5, 1 > finish 1 > finish 5 > start 3 > finish 3
 >> testFlatMap value: 6
 */
testZipAndFlatMap()
