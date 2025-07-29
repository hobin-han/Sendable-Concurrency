import PlaygroundSupport
import Foundation

// 비동기 작업이 완료될 때까지 Playground가 실행되도록 설정
PlaygroundPage.current.needsIndefiniteExecution = true

Task {
    // test here...
    await test1()
    
    // 모든 비동기 작업이 끝났으므로 Playground 실행 종료
    PlaygroundPage.current.finishExecution()
}

func test1() async {
    //
    async let a = doSomething()
    async let b = doSomething()
    //
    let resultA = await a
    let resultB = await b
    //
    print(resultA, resultB)
}

func doSomething() async -> Int {
    let random = Int.random(in: 0...10)
    print("do something (\(random)s) 🔴", Date())
    do {
        try await Task.sleep(for: .seconds(random))
        print("do something (\(random)s) 🔵", Date())
        return random
    } catch {
        return -1
    }
}
