//
//  SignalProducer+Restart.swift
//  RestartExtension
//
//  Created by Alex Peda on 8/15/16.
//  Copyright © 2016 Alex Peda. All rights reserved.
//

import Foundation
import ReactiveCocoa

extension SignalProducer {
	
	/// Creates the new signal producer that forwards all `Next` events from input and restarts the original one each time the input signal producer sends `Completed` event. Each restart should be delayed for delayInterval
	/// them on the given scheduler.
	///
	/// - parameters:
	///   - delayInterval: Interval to delay each restart loop
	///   - scheduler: A scheduler to deliver restarted sequence on
	///
	/// - returns: A producer that which applies the criteria above
    public func restart(withDelay delayInterval: NSTimeInterval, on scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        
        return SignalProducer { observer, outerDisposable in
            
            func recursiveRestartWithDelay() {
                self.delay(delayInterval, onScheduler: scheduler)
                    .startWithSignal { signal, innerDisposable in
                        setupObservations(signal, innerDisposable: innerDisposable)
                }
            }
            
            func setupObservations(signal: ReactiveCocoa.Signal<Value, Error>, innerDisposable: Disposable) {
                outerDisposable += innerDisposable
                
                signal.observeResult { result in
                    if let value = result.value {
                        observer.sendNext(value)
                    }
                }
                
                signal.observeCompleted {
                    recursiveRestartWithDelay()
                }
            }
            
            self.startWithSignal { signal, innerDisposable in
                setupObservations(signal, innerDisposable: innerDisposable)
            }
            
        }
        
    }
}

