// SharedService.swift
// SignalObserver
//
// Created by Stanislav Reznichenko on 04.12.19.

import Foundation

//service sends signals without arguments
protocol SharedServiceArgless
{
    var signal: SignalVoid {get}
}
//signal contains one argument
protocol SharedServiceArg1
{
    var signal: SignalArg<Int> {get}
}
//signal containt two arguments
protocol SharedServiceArg2
{
    var signal: SignalArg2<Int, ServiceData> {get}
}

struct ServiceData
{
    let x: Int
    let str: String
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class ServiceProvider
{
    static let provider = ServiceProvider()
    
    lazy var arglessService: SharedServiceArgless = {
        _SharedServiceArglessImpl()
    }()
    
    lazy var arg1Service: SharedServiceArg1 = {
        _SharedServiceArg1Impl()
    }()
    
    lazy var arg2Service: SharedServiceArg2 = {
        _SharedServiceArg2Impl()
    }()
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////
private class _SharedServiceArglessImpl: SharedServiceArgless
{
    @EmitterVoid var signal
    
    private lazy var _timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + 1, repeating: 0.5)
        t.setEventHandler(handler: { [weak self] in
            self?._signal.invoke()
        })
        return t
    }()
    
    init() {
        self._timer.resume()
    }
}

private class _SharedServiceArg1Impl: SharedServiceArg1
{
    @EmitterArg<Int> var signal
    
    private var _queue = DispatchQueue(label: "arg1.service.queue")
    private var _counter: Int = 0
    
    private lazy var _timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource(flags: [], queue: self._queue)
        t.schedule(deadline: .now() + 1, repeating: 2)
        t.setEventHandler(handler: { [weak self] in
            guard let strong_self = self else {
                return
            }
            strong_self._counter += 1
            strong_self._signal.invoke(strong_self._counter)
        })
        return t
    }()
    
    init() {
        self._timer.resume()
    }
}


private class _SharedServiceArg2Impl: SharedServiceArg2
{
    @EmitterArg2<Int, ServiceData> var signal
    
    private var _queue = DispatchQueue(label: "arg2.service.queue")
    private var _counter: Int = 0
    
    private lazy var _timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource(flags: [], queue: self._queue)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler(handler: { [weak self] in
            guard let strong_self = self else {
                return
            }
            let data = ServiceData(x: Int.random(in: 0..<6), str: UUID().uuidString)
            strong_self._counter += 1
            strong_self._signal.invoke(strong_self._counter, data)
        })
        return t
    }()
    
    init() {
        self._timer.resume()
    }
}

