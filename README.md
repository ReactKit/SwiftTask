SwiftTask
=========

[Promise](http://www.html5rocks.com/en/tutorials/es6/promises/) + progress + pause + cancel, using [SwiftState](https://github.com/inamiy/SwiftState) (state machine).

![SwiftTask](Screenshots/diagram.png)


## Example

### Basic

```swift
// define task
let task = Task<Float, String, NSError> { (progress, fulfill, reject, configure) in

    player.doSomethingWithProgress({ (progressValue: Float) in
        progress(progressValue) // optional
    }, completion: { (value: NSData?, error: NSError?) in
        if error == nil {
            fulfill("OK")
        }
        else {
            reject(error)
        }
    })

    // pause/resume/cancel configuration (optional)
    configure.pause = { [weak player] in
        if let p = player { p.pause() }
    }
    configure.resume = { [weak player] in
        if let p = player { p.resume() }
    }
    configure.cancel = { [weak player] in
        if let p = player { p.cancel() }
    }

}

// set then & catch
task.then { (value: String) -> Void in
    // do something with fulfilled value
}.catch { (error: NSError?, isCancelled: Bool) -> Void in
    // do something with rejected error
}

// you can call configured operations outside of Task-definition
task.pause()
task.resume()
task.cancel()
```

Notice that `player` has following methods, which will work nicely with `SwiftTask`:

- `doSomethingWithProgress(_:completion:)` (progress callback as optional)
- `pause()` (optional)
- `resume()` (optional)
- `cancel()` (optional)

One of the best example would be [Alamofire](https://github.com/Alamofire/Alamofire) (networking library)
 as seen below.

### Using [Alamofire](https://github.com/Alamofire/Alamofire)

```swift
typealias Progress = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)

// define task
let task = Task<Progress, String, NSError> { (progress, fulfill, reject, configure) in

    Alamofire.download(.GET, "http://httpbin.org/stream/100", destination: somewhere)
    .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in

        progress((bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) as Progress)

    }.response { (request, response, data, error) in

        if let error = error {
            reject(error)
            return
        }

        fulfill("OK")

    }

    return
}

// set progress & then
task.progress { progress in

    println("\(progress.bytesWritten)")
    println("\(progress.totalBytesWritten)")
    println("\(progress.totalBytesExpectedToWrite)")

}.then { (value: String) -> Void in
    // do something with fulfilled value
}
```

For more examples, please see XCTest cases.


## API Reference

### Task.init(closure:)

Define your `task` inside `closure`.

```swift
let task = Task<Float, NSString?, NSError> { (progress, fulfill, reject, configure) in

    player.doSomethingWithCompletion { (value: NSString?, error: NSError?) in
        if error == nil {
            fulfill(value)
        }
        else {
            reject(error)
        }
    }
}
```

In order to pipeline future `task.value` or `task.errorInfo` (tuple of `(error: Error?, isCancelled: Bool)`) via `then` and `catch` methods, you have to call `fulfill(value)` and `reject(error)` inside closure.

Optionally, you can call `progress(progressValue)` multiple times before calling `fulfill`/`reject` to transfer `progressValue` outside of the closure, notifying it to `task` itself.

To add `pause`/`resume`/`cancel` functionality to your `task`, use `configure` to wrap up the original one.

```swift
// NOTE: use weak to let task NOT CAPTURE player via configure
configure.pause = { [weak player] in
    if let p = player { p.pause() }
}
configure.resume = { [weak player] in
    if let p = player { p.resume() }
}
configure.cancel = { [weak player] in
    if let p = player { p.cancel() }
}
```

### task.progress(_ progressClosure:) -> task

```swift
task.progress { (progressValue: Progress) in
    println(progressValue)
    return
}.then { ... }
```

`task.progress(progressClosure)` will add `progressClosure` to observe `progressValue` which is notified from inside previous init-closure. This method will return same task, so it is useful to chain with forthcoming `then` and `catch`.


### task.then(_ closure:) -> newTask

`task.then(closure)` will return a new task which behaves differently depending on what kind of `closure` is passed in.

1. `closure` used for **fulfilled only**
2. `closure` used for both **fulfilled & rejected**

#### 1. closure used for fulfilled only = `fulfilledClosure`

`fulfilledClosure` will be invoked only when `task` is only *fulfilled*.

This case is similar to JavaScript's `promise.then(onFulfilled)`.

- `fulfilledClosure: Value -> Value2` (flow: *task => newTask*)

  ```swift
  // task will be fulfilled with value "Hello"

  task.then { (value: String) -> String in
      return "\(value) World"  // string value returns new string
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello World
      return"
  }
  ```

- `fulfilledClosure: Value -> Task` (flow: *task => task2 => newTask*)

  ```swift
  // task will be fulfilled with value "Hello"
  // task2 will be fulfilled with value "\(value) Swift"

  task.then { (value: String) -> Task<Float, String, NSError> in
      let task2 = ... // fulfilling "\(value) Swift"
      return task2
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello Swift
      return"
  }
  ```

#### 2. closure for both fulfilled & rejected = `thenClosure`

In this case, `thenClosure` will be invoked when `task` is either *fulfilled* or *rejected*. This means, `thenClosure` is mostly called in future compared to `fulfilledClosure`, which is invoked only when *fulfilled*.

This case is similar to JavaScript's `promise.then(onFulfilled, onRejected)`.

- `thenClosure: (Value?, ErrorInfo?) -> Value2` (flow: *task => newTask*)

  ```swift
  // task will be fulfilled with value "Hello"

  task.then { (value: String?, errorInfo: ErrorInfo?) -> String in
      // nil-check to find out whether task is fulfilled or rejected
      if errorInfo == nil {
          return "\(value) World"  // string value returns new string
      }
      else {
          return "\(value) Error"
      }
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello World
      return"
  }
  ```

- `thenClosure: (Value?, ErrorInfo?) -> Task` (flow: *task => task2 => newTask*)

  ```swift
  // task will be fulfilled with value "Hello"
  // task2 will be fulfilled with value "\(value) Swift"

  task.then { (value: String) -> Task<Float, String, NSError> in
      if errorInfo == nil {
          let task2 = ... // fulfilling "\(value) Swift"
          return task2
      }
      else {
          return someOtherTask
      }
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello Swift
      return"
  }
  ```

### task.catch(_ catchClosure:) -> newTask

Similar to `task.then(fulfilledClosure)` for fulfilled only, `task.catch(catchClosure)` will invoke `catchClosure` only when `task` is either *rejected* or *cancelled*.

This case is similar to JavaScript's `promise.then(undefined, onRejected)` or `promise.catch(onRejected)`.

```swift
// task will be rejected with error "Oh My God"

task.then { (value: String) -> Void in
    println("\(value)") // never reaches here
    return
}.catch { (error: NSError?, isCancelled: Bool) -> Void in
    println("\(error!)")  // Oh My God
    return
}
```

### Task.all(_ tasks:) -> newTask

`Task.all(tasks)` is a new task that performs all `tasks` simultaneously and will be:

- fulfilled when **all tasks will be fulfilled**
- rejected when **any of the task will be rejected**

### Task.any(_ tasks:) -> newTask

`Task.any(tasks)` is an opposite of `Task.all(tasks)` which will be:

- fulfilled when **any of the task will be fulfilled**
- rejected when **all tasks will be rejected**

### Task.some(_ tasks:) -> newTask

`Task.some(tasks)` is a new task that performs all `tasks` without internal rejection, and is fulfilled with given `tasks`'s fulfilled values. Note that this new task will also become *fulfilled* with empty value-array, even though all `tasks` are rejected.


## Related Articles

- [SwiftTask（Promise拡張）を使う - Qiita](http://qiita.com/inamiy/items/0756339aee35849384c3) (Japanese)


## Licence

[MIT](https://github.com/inamiy/SwiftTask/blob/master/LICENSE)
