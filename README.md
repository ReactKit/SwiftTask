SwiftTask
=========

[Promise](http://www.html5rocks.com/en/tutorials/es6/promises/) + progress + pause + cancel, using [SwiftState](https://github.com/inamiy/SwiftState) (state machine).

![SwiftTask](Screenshots/diagram.png)


## Example

### Basic

```
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
    configure.pause = { player.pause() }
    configure.resume = { player.resume() }
    configure.cancel = { player.cancel() }

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
```
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

```
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

In order to pipeline future `task.value` or `task.errorInfo` via `then` and `catch` methods, you have to call `fulfill(value)` and `reject(error)` inside closure.

Optionally, you can call `progress(progressValue)` multiple times before calling `fulfill`/`reject` to transfer `progressValue` outside of the closure, notifying it to `task` itself.

To add `pause`/`resume`/`cancel` functionality to your `task`, use `configure` tuple to wrap up the original one.

```
configure.pause = { player.pause() }
configure.resume = { player.resume() }
configure.cancel = { player.cancel() }
```

### task.progress(_ progressHandler:) -> task

```
task.progress { (progressValue: Progress) in
    println(progressValue)
    return
}.then { ... }
```

`task.progress(progressHandler)` will add `progressHandler` to observe `progressValue` which is notified in previous init-closure. This method will return same task, so it is useful to chain with forthcoming `then` and `catch`.


### task.then(_ thenClosure:) -> newTask

When `task` is *fulfilled*, `thenClosure` will be invoked, which can have 2 different closure types:

- `thenClosure: Value -> Value2` (flow: *task => newTask*)

  ```
  // task will be fulfilled with value "Hello"

  task.then { (value: String) -> String in
      return "\(value) World"  // string value returns new string
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello World
      return"
  }
  ```

- `thenClosure: Value -> Task` (flow: *task => task2 => newTask*)

  ```
  // task will be fulfilled with value "Hello"
  // task2 will be fulfilled with value "\() Swift"

  task.then { (value: String) -> Task<Float, String, NSError> in
      let task2 = ... // fulfilling "\(value) Swift"
      return task2
  }.then { (value: String) -> Void in
      println("\(value)")  // Hello Swift
      return"
  }
  ```

### task.catch(_ catchClosure:) -> newTask

Similar to `then`, but `catchClosure` will be invoked only when `task` is either *rejected* or *cancelled*.

```
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


## Licence

[MIT](https://github.com/inamiy/SwiftTask/blob/master/LICENSE)
