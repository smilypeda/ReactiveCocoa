import enum Result.NoError

infix operator <~ {
	associativity right

	// Binds tighter than assignment but looser than everything else
	precedence 93
}

public protocol BindingConsumer: class {
	associatedtype ValueType

	/// The lifetime of `self`. The binding operator uses this to determine when
	/// the binding should be teared down.
	var lifetime: Lifetime { get }

	/// Consume a value from the binding.
	func consume(_ value: ValueType)

	/// Binds a signal to a property, updating the property's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the property is
	///         deinitialized, or when the signal sends a `completed` event.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// property <~ signal
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// let disposable = property <~ signal
	/// ...
	/// // Terminates binding before property dealloc or signal's
	/// // `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - parameters:
	///   - consumer: A consumer to bind to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of property or signal's `completed` event.
	@discardableResult
	static func <~ <Source: SignalProtocol where Source.Value == ValueType, Source.Error == NoError>(consumer: Self, signal: Source) -> Disposable
}

extension BindingConsumer {
	/// Binds a signal to a property, updating the property's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the property is
	///         deinitialized, or when the signal sends a `completed` event.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// property <~ signal
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// let disposable = property <~ signal
	/// ...
	/// // Terminates binding before property dealloc or signal's
	/// // `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - parameters:
	///   - consumer: A consumer to bind to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of property or signal's `completed` event.
	@discardableResult
	public static func <~ <Source: SignalProtocol where Source.Value == ValueType, Source.Error == NoError>(consumer: Self, signal: Source) -> Disposable {
		let disposable = CompositeDisposable()
		disposable += consumer.lifetime.ended.observeCompleted(disposable.dispose)
		disposable += signal.observe { [weak consumer] event in
			switch event {
			case let .next(value):
				consumer?.consume(value)
			case .completed:
				disposable.dispose()
			case .failed, .interrupted:
				break
			}
		}

		return disposable
	}

	/// Creates a signal from the given producer, which will be immediately bound to
	/// the given property, updating the property's value to the latest value sent
	/// by the signal.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let producer = SignalProducer<Int, NoError>(value: 1)
	/// property <~ producer
	/// print(property.value) // prints `1`
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let producer = SignalProducer({ /* do some work after some time */ })
	/// let disposable = (property <~ producer)
	/// ...
	/// // Terminates binding before property dealloc or
	/// // signal's `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - note: The binding will automatically terminate when the property is
	///         deinitialized, or when the created producer sends a `completed`
	///         event.
	///
	/// - parameters:
	///   - consumer: A property to bind to.
	///   - producer: A producer to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of property or producer's `completed` event.
	@discardableResult
	public static func <~ <Source: SignalProducerProtocol where Source.Value == ValueType, Source.Error == NoError>(consumer: Self, producer: Source) -> Disposable {
		var disposable: Disposable!

		producer
			.take(during: consumer.lifetime)
			.startWithSignal { signal, signalDisposable in
				disposable = signalDisposable
				consumer <~ signal
		}

		return disposable
	}

	/// Binds `destinationProperty` to the latest values of `sourceProperty`.
	///
	/// ````
	/// let dstProperty = MutableProperty(0)
	/// let srcProperty = ConstantProperty(10)
	/// dstProperty <~ srcProperty
	/// print(dstProperty.value) // prints 10
	/// ````
	///
	/// ````
	/// let dstProperty = MutableProperty(0)
	/// let srcProperty = ConstantProperty(10)
	/// let disposable = (dstProperty <~ srcProperty)
	/// ...
	/// disposable.dispose() // terminate the binding earlier if
	///                      // needed
	/// ````
	///
	/// - note: The binding will automatically terminate when either property is
	///         deinitialized.
	///
	/// - parameters:
	///   - consumer: A property to bind to.
	///   - property: A property to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of destination property or source property
	///            producer's `completed` event.
	@discardableResult
	public static func <~ <Source: PropertyProtocol where Source.Value == ValueType>(consumer: Self, property: Source) -> Disposable {
		return consumer <~ property.producer
	}
}

extension BindingConsumer where ValueType: OptionalProtocol {
	/// Binds a signal to a property, updating the property's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the property is
	///         deinitialized, or when the signal sends a `completed` event.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// property <~ signal
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// let disposable = property <~ signal
	/// ...
	/// // Terminates binding before property dealloc or signal's
	/// // `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - parameters:
	///   - consumer: A property to bind to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of property or signal's `completed` event.
	@discardableResult
	public static func <~ <Source: SignalProtocol where Source.Value == ValueType.Wrapped, Source.Error == NoError>(consumer: Self, signal: Source) -> Disposable {
		return consumer <~ signal.map(ValueType.init(reconstructing:))
	}

	/// Creates a signal from the given producer, which will be immediately bound to
	/// the given property, updating the property's value to the latest value sent
	/// by the signal.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let producer = SignalProducer<Int, NoError>(value: 1)
	/// property <~ producer
	/// print(property.value) // prints `1`
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let producer = SignalProducer({ /* do some work after some time */ })
	/// let disposable = (property <~ producer)
	/// ...
	/// // Terminates binding before property dealloc or
	/// // signal's `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - note: The binding will automatically terminate when the property is
	///         deinitialized, or when the created producer sends a `completed`
	///         event.
	///
	/// - parameters:
	///   - consumer: A property to bind to.
	///   - producer: A producer to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of property or producer's `completed` event.
	@discardableResult
	public static func <~ <Source: SignalProducerProtocol where Source.Value == ValueType.Wrapped, Source.Error == NoError>(consumer: Self, producer: Source) -> Disposable {
		return consumer <~ producer.map(ValueType.init(reconstructing:))
	}

	/// Binds `destinationProperty` to the latest values of `sourceProperty`.
	///
	/// ````
	/// let dstProperty = MutableProperty(0)
	/// let srcProperty = ConstantProperty(10)
	/// dstProperty <~ srcProperty
	/// print(dstProperty.value) // prints 10
	/// ````
	///
	/// ````
	/// let dstProperty = MutableProperty(0)
	/// let srcProperty = ConstantProperty(10)
	/// let disposable = (dstProperty <~ srcProperty)
	/// ...
	/// disposable.dispose() // terminate the binding earlier if
	///                      // needed
	/// ````
	///
	/// - note: The binding will automatically terminate when either property is
	///         deinitialized.
	///
	/// - parameters:
	///   - consumer: A property to bind to.
	///   - property: A property to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of destination property or source property
	///            producer's `completed` event.
	@discardableResult
	public static func <~ <Source: PropertyProtocol where Source.Value == ValueType.Wrapped>(consumer: Self, property: Source) -> Disposable {
		return consumer <~ property.producer
	}
}

/// A type-erased view of a binding consumer.
public class AnyBindingConsumer<Value>: BindingConsumer {
	public typealias ValueType = Value

	let sink: (Value) -> ()

	/// The lifetime of this binding consumer. The binding operators use this to
	/// determine whether or not the binding should be teared down.
	public let lifetime: Lifetime

	/// Wrap an binding consumer.
	///
	/// - parameter:
	///   - consumer: The binding consumer to be wrapped.
	public init<U: BindingConsumer where U.ValueType == Value>(_ consumer: U) {
		self.sink = consumer.consume
		self.lifetime = consumer.lifetime
	}

	/// Create a binding consumer.
	///
	/// - parameter:
	///   - sink: The sink to receive the values from the binding.
	///   - lifetime: The lifetime of the binding consumer.
	public init(sink: (Value) -> (), lifetime: Lifetime) {
		self.sink = sink
		self.lifetime = lifetime
	}

	/// Consume a value.
	public func consume(_ value: Value) {
		sink(value)
	}
}
