# signal_observer
Signal-Slot approach for Swift (if Combine is not available)

This is an example how to build **MulticastDelegate**. If one of the requirements of your project is supporting iPhone SE
all features from iOS 13 are unavailable for you. So no Combine, no Promises. Of course there are great third party solutions
like **RxSwift**. But sometimes bringing so big dependencies into project is not a good option. Especially when the project is
not big and your architecture is not based on reactivity. So there was a project where i needed some kind of analog 
Combine's [assign](https://developer.apple.com/documentation/combine/just/assign(to:on:)) and [sink](https://developer.apple.com/documentation/combine/just/sink(receivevalue:)).

Implementation is one-file library. From one side we have source of signals (events) - emitter. From another side - set of slots (hi QT).
Slot can be either a method of an object or closure. There are 3 variants of emitter-signal:
1. Without arguments: `EmitterVoid`, `SignalVoid`.
2. With one argument: `EmitterArg<ArgType>`, `SignalArg<Argtype>`.
3. With two arguments: `EmitterArg2<Arg1Type, Arg2Type>`, `SignalArg2<Arg1Type, Arg2Type>`.

If you need more just wrap arguments into tuple.

This approach based on the fact that method itself is a closure
with signature 
```swift
(Target) -> (ArgType...) -> ReturnType
``` 
This is closure with one argument and it returns another closure. 
Emitter is property wrapper around Signal with one method `invoke`. So signal can be send only from private scope. 

Example of Emitter
------------
```swift
//Some service has two events: with 2 arguments and without arguments
protocol Service {
	var signal: SignalArg2<Int, String> {get}
	var arglessSignal: SignalVoid {get}
}

class ServiceImpl: Service {
		
	@EmitterArg2<Int, String> var signal

	@EmitterVoid var arglessSignal

	private func someFunction() {
		self._signal.invoke(10, "event string")
	}

	private func anotherFunction() {
		self._arglessSignal.invoke()
	}
}
``` 

Example of Observer
------------
Any object can act as an observer and does not need to conform any protocol.
```swift
class FirstObserver {

	private func didReceiveSignal(x: Int, str: String) {
		print("received x: \(x), str: \(str)")
	}

	private func didReceiveArglessSignal() {
		print("received argless signal")
	}

	func connectToServiceSignals(service: Service) {
		service.signal.connect(self, FirstObserver.didReceiveSignal)
		service.arglessSignal.connect(self, FirstObserver.didReceiveArglessSignal)
	}
}

class AnotherObject {

	func didReceiveArglessSignal() {
		print("received argless signal")
	}
}

var observer1: FirstObserver?
observer1 = FirstObserver(...)
let service = ServiceImpl(...)
observer1.connectToServiceSignals(service)
//observer now receives two signals

let another_observer = AnotherObject()
service.arglessSignal.connect(another_observer, AnotherObjsct.didReceiveArglessSignal)
//this observer receives one signal

observer1 = nil
//after deallocation observers will be removed from emitter
```

Handle Signal in the background queue
------------
By default signal is handled in the main queue. But emitter can `invoke` signal from any thread and signal can be observed in another thread.
```swift
class SecondObserver {

	func didReceiveSignal(x: Int, str: String) {
		print("received x: \(x), str: \(str)")
	}
}


let observer2 = SecondObserver()
var queue = DispatchQueue(label: "some.queue")
service.signal.connect(observer2, SecondObserver.didReceiveSignal, queue)

```
or signal can be observed in the same thread as it was invoked
```swift
service.signal.connect(observer2, SecondObserver.didReceiveSignal, nil)

```

Control the Observer
------------
You can store a handle to observer to control it.
```swift
var observerHandle1: SignalObserver? 
var observerHandle2: SignalObserver? 

observerHandle1 = service.signal.connect(observer1, FirstObserver.didReceiveSignal, queue)
observerHandle2 = service.signal.connect(observer2, SecondObserver.someFunctionWithTwoArgumentsIntAndString)
//at this moment both observers receive signal

observerHandle1.suspend()
//at this moment only second observer is active

observerHandle1.resume()
//both observer are active again

observerHandle2.cancel()
//second observer is invalidated
observerHandle2 = nil

```

Transform signature
------------
You can transform observer's signature if you by some reason cannot subclass it or add an extension.
```swift
struct ServiceData {
	let x: Int
	let str: String
}

class Service {
		
	@EmitterArg2<Int, ServiceData> var signal

	private func someFunction() {
		let packet_id = 89
		let data = ServiceData(x: 999, str: "message")
		self._signal.invoke(packet_id, data)
	}
}


final class Object {
	func didReceiveSignal(x: Int, str: String) {
		print("received x: \(x), str: \(str)")
	}
}


let service = Service()
let observer = Object()

service.signal.map(observer, Object.didReceiveSignal, {($0, $1.str)})
```
Credits
=======
SignalObserver was built by Stan Reznichenko from [Lohika](www.lohika.com.ua) 
