//
//  SU_SignalObserver.swift
//  SingularityUtils/SignalObserver
//
//  Created by Stanislav Reznichenko on 04.08.19.
//

//to do : use swift-atomics instead of lock
import Foundation

protocol SU_SignalObserver
{
    func cancel()
    func suspend()
    func resume()
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Emitter traits
protocol SU_EmitterTraits
{
    associatedtype Signature
}

protocol SU_EmitterArg1Traits: SU_EmitterTraits where Signature == (Arg) -> Void
{
    associatedtype Arg
}

protocol SU_EmitterArg2Traits: SU_EmitterTraits where Signature == (Arg1, Arg2) -> Void
{
    associatedtype Arg1
    associatedtype Arg2
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Tags
struct SU_VoidTag: SU_EmitterTraits
{
    typealias Signature = () -> Void
}

struct SU_Arg1Tag<A>: SU_EmitterArg1Traits
{
    typealias Arg = A
    typealias Signature = (A) -> Void
}

struct SU_Arg2Tag<A1, A2>: SU_EmitterArg2Traits
{
    typealias Arg1 = A1
    typealias Arg2 = A2
    typealias Signature = (Arg1, Arg2) -> Void
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Observer holder
private protocol _ObserverHolder {
    associatedtype Observer
    func getObserver() -> Observer?
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
private class _ObserverHolderImpl<Target: AnyObject, Traits: SU_EmitterTraits>: _ObserverHolder
{
    typealias ObserverGetter = (Target) -> Traits.Signature
    
    private weak var _target    : Target?
    private let _observerGetter : ObserverGetter
    
    init(_ target: Target, _ observerGetter: @escaping ObserverGetter) {
        _target = target
        _observerGetter = observerGetter
    }
    
    deinit {
        //print("\(type(of: self))::\(#function)")
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func getObserver() -> Traits.Signature? {
        guard let target = _target else {
            return nil
        }
        return self._observerGetter(target)
    }
}

private class _TransformedArgObserverHolder<Target: AnyObject, Traits: SU_EmitterArg1Traits, A>: _ObserverHolder
{
    private weak var _target    : Target?
    private let _observerGetter : (Target) -> (A) -> Void
    private let _transform      : (Traits.Arg) -> A
    
    init(_ target: Target,
         _ observerGetter: @escaping ((Target) -> (A) -> Void),
         _ transformer: @escaping ((Traits.Arg) -> A)) {
        _target = target
        _observerGetter = observerGetter
        _transform = transformer
    }
    
    func getObserver() -> Traits.Signature? {
        guard let target = _target else {
            return nil
        }
        return {[weak self] (arg: Traits.Arg) in
            guard let strong_self = self else {
                return
            }
            strong_self._observerGetter(target)(strong_self._transform(arg))
        }
    }
}

private class _TransformedArg2ObserverHolder<Target: AnyObject, Traits: SU_EmitterArg2Traits, A1, A2>: _ObserverHolder
{
    private weak var _target    : Target?
    private let _observerGetter : (Target) -> (A1, A2) -> Void
    private let _transform      : (Traits.Arg1, Traits.Arg2) -> (A1, A2)
    
    init(_ target: Target,
         _ observerGetter: @escaping ((Target) -> (A1, A2) -> Void),
         _ transformer: @escaping ((Traits.Arg1, Traits.Arg2) -> (A1, A2))) {
        _target = target
        _observerGetter = observerGetter
        _transform = transformer
    }
    
    func getObserver() -> Traits.Signature? {
        guard let target = _target else {
            return nil
        }
        return {[weak self] (arg1: Traits.Arg1, arg2: Traits.Arg2) in
            guard let strong_self = self else {
                return
            }
            let transformed_args = strong_self._transform(arg1, arg2)
            strong_self._observerGetter(target)(transformed_args.0, transformed_args.1)
        }
    }
}

private class _ObserverClosureHolder<Traits: SU_EmitterTraits>: _ObserverHolder
{
    private let _observer: Traits.Signature
    init (_ observer: Traits.Signature) {
        self._observer = observer
    }
    
    func getObserver() -> Traits.Signature? {
        return self._observer
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- node state
private class _NodeState<T>
{
    let deleted: Bool
    let next: T?
    
    init()
    {
        self.deleted = false
        self.next = nil
    }
    
    init(nextNode: T?, deleted: Bool)
    {
        self.next = nextNode
        self.deleted = deleted
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- AnyObserverNode
private class _AnyObserver<T: SU_EmitterTraits>: SU_SignalObserver, _ObserverHolder
{
    private (set) var state : _NodeState<_AnyObserver>
    private var _suspended  : Bool = false
    private var _getter     : () -> T.Signature?
    private let _queue      : DispatchQueue?
    private let _lock       = NSLock()
    
    init<H: _ObserverHolder>(_ next: _AnyObserver?, _ holder: H, _ queue: DispatchQueue? = nil) where H.Observer == T.Signature {
        self.state = _NodeState(nextNode: next, deleted: false)
        self._getter =  holder.getObserver
        self._queue = queue
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //SU_SignalObserver
    func cancel() {
        self.flagAsDeleted()
    }
    
    func suspend() {
        self._suspended = true
    }
    
    func resume() {
        self._suspended = false
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func flagAsDeleted() {
        self._lock.lock()
        defer {self._lock.unlock()}
        let old_state = self.state
        if old_state.deleted {
            return
        }
        let new_state = _NodeState(nextNode: old_state.next, deleted: true)
        self.state = new_state
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func getObserver() -> T.Signature? {
        if !self.state.deleted {
            return self._getter()
        }
        return nil
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func getNext() -> _AnyObserver? {
        self._lock.lock()
        defer {self._lock.unlock()}
        while let next = self.state.next {
            let next_state = next.state
            if next.getObserver() == nil || next_state.deleted {
                //remove invalid node
                let new_next = next.state.next
                let new_state = _NodeState(nextNode: new_next, deleted: self.state.deleted)
                self.state = new_state
                //
            } else {
                return next
            }
        }
        return nil
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- AnyObserver for 1 arg
private extension _AnyObserver where T: SU_EmitterArg1Traits
{
    func invoke(_ arg: T.Arg) {
        guard let observer = self.getObserver() else {
            self.flagAsDeleted()
            return
        }
        if self._suspended {
            return
        }
        if let queue = self._queue {
            queue.async(execute: {[weak self] in
                guard let strong_self = self else {
                    return
                }
                if let observer = strong_self.getObserver() {
                    if !strong_self._suspended {
                        observer(arg)
                    }
                } else {
                    strong_self.flagAsDeleted()
                }
            })
        } else {
            observer(arg)
        }
    }
}
//MARK:- AnyObserver for 2 arg
private extension _AnyObserver where T: SU_EmitterArg2Traits
{
    func invoke(_ arg1: T.Arg1, _ arg2: T.Arg2) {
        guard let observer = self.getObserver() else {
            self.flagAsDeleted()
            return
        }
        if self._suspended {
            return
        }
        if let queue = self._queue {
            queue.async(execute: {[weak self] in
                guard let strong_self = self else {
                    return
                }
                if let observer = strong_self.getObserver() {
                    if !strong_self._suspended {
                        observer(arg1, arg2)
                    }
                } else {
                    strong_self.flagAsDeleted()
                }
            })
        } else {
            observer(arg1, arg2)
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Any Observer for void
private extension _AnyObserver where T.Signature == () -> Void
{
    func invoke() {
        guard let observer = self.getObserver() else {
            self.flagAsDeleted()
            return
        }
        if self._suspended {
            return
        }
        if let queue = self._queue {
            queue.async(execute: {[weak self] in
                guard let strong_self = self else {
                    return
                }
                if let observer = strong_self.getObserver() {
                    if !strong_self._suspended {
                        observer()
                    }
                } else {
                    strong_self.flagAsDeleted()
                }
            })
        } else {
            observer()
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Signal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
final class SU_Signal<T: SU_EmitterTraits>
{
    private let _emitter: SU_Emitter<T>
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    init(_ emitter: SU_Emitter<T>) {
        self._emitter = emitter
        //print("\(type(of: self))::\(#function)")
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @discardableResult
    func connect<Target: AnyObject>(_ target: Target,
                                    _ action: @escaping ((Target) -> T.Signature),
                                    _ queue: DispatchQueue? = DispatchQueue.main) -> SU_SignalObserver {
        let holder = _ObserverHolderImpl<Target, T>(target, action)
        self._emitter._lock.lock()
        defer {self._emitter._lock.unlock()}
        let old_head = self._emitter._headNode
        let new_head = _AnyObserver<T>(old_head, holder, queue)
        self._emitter._headNode = new_head
        return new_head
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @discardableResult
    func connect(_ action: T.Signature,  _ queue: DispatchQueue? = DispatchQueue.main) -> SU_SignalObserver {
        let holder = _ObserverClosureHolder<T>(action)
        self._emitter._lock.lock()
        defer {self._emitter._lock.unlock()}
        let old_head = self._emitter._headNode
        let new_head = _AnyObserver<T>(old_head, holder, queue)
        self._emitter._headNode = new_head
        return new_head
    }
}

extension SU_Signal where T: SU_EmitterArg1Traits
{
    @discardableResult
    func map<Target: AnyObject, A>(_ target: Target,
                                   _ action: @escaping ((Target) -> (A) -> Void),
                                   _ transform: @escaping ((T.Arg) -> A),
                                   _ queue: DispatchQueue? = DispatchQueue.main) -> SU_SignalObserver {
        let holder = _TransformedArgObserverHolder<Target, T, A>(target, action, transform)
        self._emitter._lock.lock()
        defer {self._emitter._lock.unlock()}
        let old_head = self._emitter._headNode
        let new_head = _AnyObserver<T>(old_head, holder, queue)
        self._emitter._headNode = new_head
        return new_head
    }
}

extension SU_Signal where T: SU_EmitterArg2Traits
{
    @discardableResult
    func map<Target: AnyObject, A1, A2>(_ target: Target,
                                        _ action: @escaping ((Target) -> (A1, A2) -> Void),
                                        _ transform: @escaping ((T.Arg1, T.Arg2) -> (A1, A2)),
                                        _ queue: DispatchQueue? = DispatchQueue.main) -> SU_SignalObserver {
        let holder = _TransformedArg2ObserverHolder<Target, T, A1, A2>(target, action, transform)
        self._emitter._lock.lock()
        defer {self._emitter._lock.unlock()}
        let old_head = self._emitter._headNode
        let new_head = _AnyObserver<T>(old_head, holder, queue)
        self._emitter._headNode = new_head
        return new_head
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Emitter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
final class SU_Emitter<T: SU_EmitterTraits>
{
    var signal: SU_Signal<T> {
        return SU_Signal<T>(self)
    }
    fileprivate var _headNode: _AnyObserver<T>?
    fileprivate let _lock = NSLock()
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func cancelAllObservers() {
        self._lock.lock()
        defer {self._lock.unlock()}
        guard var node = self._getHead() else {
            return
        }
        node.cancel()
        while let next = node.getNext() {
            next.cancel()
            node = next
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    private func _getHead() -> _AnyObserver<T>? {
        guard var node = self._headNode else {
            return nil
        }
    
        while node.getObserver() == nil || node.state.deleted {
            if let next = node.state.next {
                self._headNode = next
                node = next
            } else {
                self._headNode = nil
                return nil
            }
        }
        return node
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Emitter for 1 arg
extension SU_Emitter where T: SU_EmitterArg1Traits
{
    func invoke(_ arg: T.Arg) {
        self._lock.lock()
        defer {self._lock.unlock()}
        guard var node = self._getHead() else {
            return
        }
        node.invoke(arg)
        while let next = node.getNext() {
            next.invoke(arg)
            node = next
        }
    }
}
//MARK:- Emitter for 2 args
extension SU_Emitter where T: SU_EmitterArg2Traits
{
    func invoke(_ arg1: T.Arg1, _ arg2: T.Arg2) {
        self._lock.lock()
        defer {self._lock.unlock()}
        guard var node = self._getHead() else {
            return
        }
        node.invoke(arg1, arg2)
        while let next = node.getNext() {
            next.invoke(arg1, arg2)
            node = next
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//MARK:- Emitter for void
extension SU_Emitter where T.Signature == () -> Void
{
    func invoke() {
        self._lock.lock()
        defer {self._lock.unlock()}
        guard var node = self._getHead() else {
            return
        }
        node.invoke()
        while let next = node.getNext() {
            next.invoke()
            node = next
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
typealias SignalObserver = SU_SignalObserver

typealias SignalVoid = SU_Signal<SU_VoidTag>
typealias SignalArg<T> = SU_Signal<SU_Arg1Tag<T>>
typealias SignalArg2<T1, T2> = SU_Signal<SU_Arg2Tag<T1, T2>>

@propertyWrapper
struct EmitterVoid
{
    private let _emitter = SU_Emitter<SU_VoidTag>()
    
    var wrappedValue: SU_Signal<SU_VoidTag> {
        return self._emitter.signal
    }
    
    func invoke() {
        self._emitter.invoke()
    }
    
    func cancelAllObservers() {
        self._emitter.cancelAllObservers()
    }
}

@propertyWrapper
struct EmitterArg<T>
{
    private let _emitter = SU_Emitter<SU_Arg1Tag<T>>()
    
    var wrappedValue: SU_Signal<SU_Arg1Tag<T>> {
        self._emitter.signal
    }
    
    func invoke(_ arg: T) {
        self._emitter.invoke(arg)
    }
    
    func cancelAllObservers() {
        self._emitter.cancelAllObservers()
    }
}

@propertyWrapper
struct EmitterArg2<T1, T2>
{
    private let _emitter = SU_Emitter<SU_Arg2Tag<T1, T2>>()
    
    var wrappedValue: SU_Signal<SU_Arg2Tag<T1, T2>> {
        self._emitter.signal
    }
    
    func invoke(_ arg1: T1, _ arg2: T2) {
        self._emitter.invoke(arg1, arg2)
    }
    
    func cancelAllObservers() {
        self._emitter.cancelAllObservers()
    }
}
