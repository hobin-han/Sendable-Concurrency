//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport


/*
 Task {} 안에 여러개의 비동기 로직이 포함되어있을 때,
 Task 의 cancel() 이 호출되면 어떻게 동작하는가?
 */


// MARK: - Tasker

class Tasker {
    private var continuation: CheckedContinuation<Void, Never>?
    
    deinit {
//        print("deinit", Task.isCancelled)
    }
    
    func sleepWithTaskCancellationHandler(sec: Int) async {
        await withTaskCancellationHandler {
            await sleepWithCheckedContinuation(sec: sec)
        } onCancel: {
            if continuation != nil {
                print("onCancel", sec)
            }
            continuation?.resume(returning: ())
        }
    }
    
    func sleepWithCheckedContinuation(sec: Int) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            guard Task.isCancelled == false else {
                if self.continuation != nil {
                    print("Task.isCancelled !", sec)
                }
                self.continuation?.resume(returning: ())
                return
            }
            
            print("sleep start", sec)
            self.sleep(sec) { [weak self] in
                // Task.isCancelled
                if self?.continuation != nil {
                    print("sleep finish", sec)
                }
                self?.continuation?.resume(returning: ())
                
            }
        }
    }
    
    private func sleep(_ sec: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sec), execute: {
            completion()
        })
    }
}



// MARK: - MyViewController

class MyViewController : UIViewController {
    private let label = UILabel()
    
    private var task: Task<Void, Never>?
    
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white

        label.frame = CGRect(x: 150, y: 200, width: 200, height: 20)
        label.text = "Hello World!"
        label.textColor = .black
        view.addSubview(label)
        
        let button = UIButton()
        button.frame = CGRect(x: 150, y: 300, width: 100, height: 30)
        button.backgroundColor = .systemBlue
        button.setTitle("Start", for: .normal)
        button.setTitle("Stop", for: .selected)
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        view.addSubview(button)
        
        
        let stackView = UIStackView(frame: CGRect(x: 50, y: 50, width: 170, height: 50))
        stackView.distribution = .fillProportionally
        stackView.spacing = 8
        stackView.backgroundColor = .systemYellow
        view.addSubview(stackView)
        ["hi", "hello", "hi i am bamiboo"].forEach { string in
            let label = UILabel()
            label.text = string
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.backgroundColor = .systemGray
            stackView.addArrangedSubview(label)
        }
        
        self.view = view
    }
    
    @objc private func buttonTapped(_ button: UIButton) {
        //
        let startTask = testWithCheckedContinuation1
//        let startTask = testWithCheckedContinuation2
        
        // ------ 테스트 1
//        let startTask = startTaskWithCheckedContinuation
        // ------ 테스트 2
//        let startTask = startTaskWithCancellationHandler
        // ------ 테스트 3
//        let startTask = startWithMultipleTask
        
        print("👉", button.isSelected ? "Stop" : "Start", "button")
        button.isSelected ? stopTask() : startTask()
        button.isSelected.toggle()
    }
    
    private func stopTask() {
        // task = nil 로 대체될 수 없다.
        task?.cancel()
    }
}

// MARK: Task Actor 테스트
extension MyViewController {
    @MainActor
    class MainTaskActor {
        func execute() async {
            await withCheckedContinuation { c in
                print("Thread.isMainThread", Thread.isMainThread)
                c.resume()
            }
        }
    }
    
    func testWithCheckedContinuation1() {
        Task { @MainActor in
            await MainTaskActor().execute()
        }
    }
    
    func testWithCheckedContinuation2() {
        Task.detached(priority: .userInitiated) {
            await MainTaskActor().execute()
        }
    }
}


// MARK: Task cancel() 테스트

extension MyViewController {
    /**
     테스트 1
     
     Task {} 가 cancel() 호출되더라도 아래 로직은 모두 호출이 된다.
     따라서 withCheckedContinuation operation 내부 최상단에서 Task.isCancelled 여부를 체크해주는 것이 좋다.
     
     그렇게되면
     이미 진행중이던 비동기 동작은 완료될때까지 기다려지고,
     그 이후에 시작되는 비동기 동작은 Task.isCancelled 로 인해 execute 로직을 타지 않게 된다.
     
     단, Tasker 자체적으로는 Task canel 여부가 감지되지 않는다.
     즉, cancel 이 호출되었다 해도 이미 작업중인 작업 대해 바로 resume 을 호출해줄수는 없다.
     (⚠️ example() 함수처럼 오래걸리는 단일 비동기 작업인 경우, Task 의 cancel 동작이 의미가 없어진다)
     
     👉 Start button
     sleep start 1
     sleep finish 1
     sleep start 2
     👉 Stop button
     sleep finish 2                 // finish 될 때까지 기다린다.
     Task.isCancelled ! 3
     Task.isCancelled ! 4
     Task.isCancelled ! 5
     Task.isCancelled ! 6
     */
    private func startTaskWithCheckedContinuation() {
        task = Task {
            for i in 1...6 { // 여러개의 비동기 로직을 for 문으로 대체.
                label.text = "\(i) ..."
                await Tasker().sleepWithCheckedContinuation(sec: i)
            }
        }
    }
    
    /**
     테스트 2
     
     Task {} 가 cancel() 호출되더라도 아래 로직은 모두 호출되는 것은 동일하며,
     cancel() 호출됨과 동시에 진행중인 비동기 작업과 아직 호출되지 않은 작업의 withTaskCancellationHandler onCancel 이 호출된다.
     
     아직 호출되지 않은 작업의 비동기 동작은 위와 동일하게 Task.isCancelled 로 인해 execute 로직을 타지 않게 된다.
     
     ⚠️ 다만, 이미 진행중이던 비동기 작업은 withTaskCancellationHandler onCancel 도 호출되지만 비동기 작업도 완료가된다??
     DispatchQueue 내부 Task.isCancelled 가 먹히지 않음? 왜지? 항상 false 값을 가짐... global thread 로 테스트해도 동일...
     (근데 왜 resume 여러번 호출 crash 도 발생을 안하냐... 불안하게...)
     
     가 아니라? continuation resume 이 호출되면 continuation 가 자동으로 nil 로 해제가 된다!! 굳
     
     👉 Start button
     sleep start 1
     sleep finish 1
     sleep start 2
     👉 Stop button
     onCancel 2                     // 바로 onCancel 호출되는 것 확인.
     Task.isCancelled ! 3
     Task.isCancelled ! 4
     Task.isCancelled ! 5
     Task.isCancelled ! 6
     */
    private func startTaskWithCancellationHandler() {
        task = Task {
            for i in 1...6 { // 여러개의 비동기 로직을 for 문으로 대체.
                label.text = "\(i) ..."
                await Tasker().sleepWithTaskCancellationHandler(sec: i)
            }
        }
    }
    
    /**
     🥸 추가로 주의할 점!! (테스트 2 에서)
     private var continuation: CheckedContinuation<Void, Never>?
     로 선언해둔 프로퍼티가 자동 메모리 해제된다??
     =>
     resume 이 호출되면서 Tasker 객체도 메모리 해제된다.
     
     if self?.continuation != nil 조건 없이 print 를 해본다면?
     
     👉 Start button
     sleep start 1
     sleep finish 1
     sleep start 2
     👉 Stop button
     onCancel 2
     onCancel 3                     // continuation is nil
     Task.isCancelled ! 3
     onCancel 4                     // continuation is nil
     Task.isCancelled ! 4
     onCancel 5                     // continuation is nil
     Task.isCancelled ! 5
     onCancel 6                     // continuation is nil
     Task.isCancelled ! 6
     sleep finish 2                  // continuation is nil
     
     
     (테스트 1 에서는)
     진행중에 Task.cancel() 의 간섭을 받지 않으므로
     continue?.resume 이 여러번 호출될 수 없어 print 시 nil 체크가 불필요했다!
     */
    
    
    
    /**
     ⚠️ 내부에 Task 로 한번 더 감싸져있는 경우, 내부 Task 까지 cancel() 이 처리되지는 않음. (1~6 단계 모두 정상 실행됨)
     상하위 구조로 연결된 Task 에 대해서만 cancel 이 전달됨.
     --------------------------------------------------------
     - Tasker().sleepWithTaskCancellationHandler(sec: i) 호출시
        - withTaskCancellationHandler onCancel 호출되지 않음.
        - Tasker 의 Task.isCancelled 값은 항상 false.
     - Tasker().sleepWithCheckedContinuation(sec: i) 호출시
        - Tasker 의 Task.isCancelled 값은 항상 false.
     */
    private func startWithMultipleTask() {
        task = Task {
            Task {
                for i in 1...6 { // 여러개의 비동기 로직을 for 문으로 대체.
                    label.text = "\(i) ..."
                    await Tasker().sleepWithTaskCancellationHandler(sec: i)
                    // await Tasker().sleepWithCheckedContinuation(sec: i)
                }
            }
        }
    }
}
    
// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()




// MARK: - 내가 생각하는 Closure → Swift Concurrency 최종 형태.

class CancellableSleepTasker {
    private var continuation: CheckedContinuation<Void, Never>?
    
    func execute(sec: Int) async {
        await withTaskCancellationHandler {
            await executeWithCheckedContinuation(sec: sec)
        } onCancel: { // onCancel 은 비동기 작업 진행중인 건에 대해서만 호출된다. 나머지는 Task.isCancelled 로 체크해야 한다.
            continuation?.resume(returning: ()) // continuation 가 nil 일 수 있음 주의
        }
    }
    
    private func executeWithCheckedContinuation(sec: Int) async {
        await withCheckedContinuation { [weak self] continuation in
            self?.continuation = continuation
            
            guard Task.isCancelled == false else {
                self?.continuation?.resume(returning: ())
                return
            }
            
            self?.sleep(sec: sec) { [weak self] in
                self?.continuation?.resume(returning: ()) // continuation 가 nil 일 수 있음 주의
            }
        }
    }
    
    private func sleep(sec: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sec), execute: {
            completion()
        })
    }
}

/**
 네트워크 통신이 필요하거나 다운로드를 하거나 와 같이 오래걸리는 비동기작업이 아닌 경우에는 간단하게는 이렇게 호출해도 된다.
 그대신 진행중이던 Task cancel() 이 호출되더라도 비동기 로직이 끝날때까지 기다리게 된다.
 아직 실행되지 않은 비동기 로직이라면 Task.isCancelled 로 걸러져 비동기 로직을 타지 않는다.
 */
class SleepTasker {
    func execute(sec: Int) async {
        await withCheckedContinuation { continuation in
            guard !Task.isCancelled else {
                continuation.resume(returning: ())
                return
            }
            
            sleep(sec: sec) {
                continuation.resume(returning: ())
            }
        }
    }
    
    private func sleep(sec: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sec), execute: {
            completion()
        })
    }
}
