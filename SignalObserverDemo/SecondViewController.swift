// SecondViewController.swift
// SignalObserver
//
// Created by Stanislav Reznichenko on 04.12.19.

import UIKit

class SecondViewController: UIViewController
{
    private class _SeparatedObserver
    {
        private var _label: UILabel
        
        init(lable: UILabel) {
            self._label = lable
        }
        
        deinit {
            print("\(type(of: self))::\(#function)")
        }
        
        func _onSignal(arg1: Int, argData: ServiceData) {
            let log_txt = """
            reseived arg2 signal.
            arg1: \(arg1),
            data.x: \(argData.x),
            data.id: \(argData.str)
            """
            self._label.text = log_txt
        }
    }
    
    private var _observerHolder: _SeparatedObserver?
    private var _observer: SignalObserver?
    private var _closureObserver: SignalObserver?
    private var _closureObserverQueue = DispatchQueue(label: "closure.observer.queue", attributes: .concurrent)
    @IBOutlet private var _observerLb: UILabel!
    @IBOutlet private var _closureObserverLb: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self._createAndConnect()
    }

    private func _createAndConnect() {
        let holder = _SeparatedObserver(lable: self._observerLb)
        self._observerHolder = holder
        let provider = ServiceProvider.provider
        self._observer = provider.arg2Service.signal.connect(holder,
                                                             _SeparatedObserver._onSignal)
    }
    ////////////////////////////////////////////////////////////////////////////////////////////
    //ui handlers
    @IBAction private func _onCancelConnectTap(sender: UIButton) {
        if let observer = self._observer {
            observer.cancel()
            self._observer = nil
            sender.setTitle("reconnect observer", for: .normal)
        } else {
            if let holder = self._observerHolder {
                let provider = ServiceProvider.provider
                self._observer = provider.arg2Service.signal.connect(holder,
                                                                     _SeparatedObserver._onSignal)
                sender.setTitle("cancel observer", for: .normal)
            }
        }
    }
    
    @IBAction private func _onDeallocCreateTap(sender: UIButton) {
        if self._observerHolder != nil {
            self._observerHolder = nil
            sender.setTitle("recreate observer object", for: .normal)
        } else {
            self._createAndConnect()
            sender.setTitle("dealloc observer object", for: .normal)
        }
    }
    
    @IBAction private func _closureObserverTap(sender: UIButton) {
        if let closure_observer = self._closureObserver {
            closure_observer.cancel()
            self._closureObserver = nil
            sender.setTitle("connect closure observer", for: .normal)
        } else {
            let provider = ServiceProvider.provider
            self._closureObserver = provider.arg2Service.signal.connect({[weak self] (arg1, arg2) in
                guard let strong_self = self else {
                    return
                }
                assert(!Thread.isMainThread)
                let log_txt = """
                reseived arg2 signal.
                arg1: \(arg1),
                data.x: \(arg2.x),
                data.id: \(arg2.str)
                """
                DispatchQueue.main.async {
                    strong_self._closureObserverLb.text = log_txt
                }
            }, self._closureObserverQueue)
            
            sender.setTitle("cancel closure observer", for: .normal)
        }
    }
    
    deinit {
        print("\(type(of: self))::\(#function)")
    }
}
