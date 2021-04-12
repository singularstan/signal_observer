// ViewController.swift
// SignalObserver
//
// Created by Stanislav Reznichenko on 04.12.19.

import UIKit

class FirstViewController: UIViewController
{
    private var _oneArgObserver: SignalObserver?
    private var _twoArgsObserver: SignalObserver?
    
    private var _arglessSignals: Int = 0
    private var _oneArgSignalSuspended: Bool = false
    private var _twoArgsSignalSuspended: Bool = false
    
    @IBOutlet private var _arglessSignalLb: UILabel!
    @IBOutlet private var _arg1SignalLb: UILabel!
    @IBOutlet private var _arg2SignalLb: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let provider = ServiceProvider.provider
        //emitter will remove observer after object deallocation
        //if you dont need to control observer dont store observer
        provider.arglessService.signal.connect(self, FirstViewController._onArglessSignal)
        //to control observer just store it as variable and call suspend/resume
        self._oneArgObserver = provider.arg1Service.signal.connect(self, FirstViewController._onOneArgSignal)
        self._twoArgsObserver = provider.arg2Service.signal.connect(self, FirstViewController._onTwoArgSignal)
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //observers
    private func _onArglessSignal() {
        print("reseived argless signal")
        self._arglessSignals += 1
        self._arglessSignalLb.text = "Reseived \(self._arglessSignals) argless signals"
    }
    
    private func _onOneArgSignal(_ counter: Int) {
        let log_txt = "reseived arg1 signal. counter: \(counter)"
        print(log_txt)
        self._arg1SignalLb.text = log_txt
    }

    private func _onTwoArgSignal(arg1: Int, argData: ServiceData) {
        let log_txt = """
        reseived arg2 signal.
        arg1: \(arg1),
        data.x: \(argData.x),
        data.id: \(argData.str)
        """
        print(log_txt)
        self._arg2SignalLb.text = log_txt
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //ui handlers
    @IBAction private func _arg1BtnTap(sender: UIButton) {
        if self._oneArgSignalSuspended {
            sender.setTitle("Suspend one-arg observer", for: .normal)
            self._oneArgObserver?.resume()
        } else {
            sender.setTitle("Resume one-arg observer", for: .normal)
            self._oneArgObserver?.suspend()
        }
        self._oneArgSignalSuspended.toggle()
    }
    
    @IBAction private func _arg2BtnTap(sender: UIButton) {
        if self._twoArgsSignalSuspended {
            sender.setTitle("Suspend two-arg observer", for: .normal)
            self._twoArgsObserver?.resume()
        } else {
            sender.setTitle("Resume two-arg observer", for: .normal)
            self._twoArgsObserver?.suspend()
        }
        self._twoArgsSignalSuspended.toggle()
    }
}

