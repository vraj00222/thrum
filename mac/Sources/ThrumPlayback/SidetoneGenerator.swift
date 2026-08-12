import AVFoundation

/// 600Hz sine, gated on and off with the pulses. Nearly everyone runs haptic plus
/// audio together — haptic-only is the party trick, not the default.
public final class SidetoneGenerator {

    public var frequency: Double = 600
    public var volume: Float = 0.25

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var phase: Double = 0
    private var sampleRate: Double = 44100

    /// Target amplitude, read by the render thread. The 5ms ramp toward it is what
    /// keeps gating a sine from clicking on every one of 2000 taps.
    private var gate = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private var level = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    public init() {
        gate.pointee = 0
        level.pointee = 0
    }

    deinit {
        gate.deallocate()
        level.deallocate()
    }

    public func start() throws {
        guard source == nil else { return }
        let format = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let twoPiOverRate = 2 * Double.pi * frequency / sampleRate
        let rampPerSample = Float(1.0 / (0.005 * sampleRate))
        let gatePtr = gate, levelPtr = level
        var localPhase = 0.0
        let amplitude = volume

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let target = gatePtr.pointee
                var current = levelPtr.pointee
                if current < target { current = min(target, current + rampPerSample) }
                else if current > target { current = max(target, current - rampPerSample) }
                levelPtr.pointee = current

                let value = Float(sin(localPhase)) * current * amplitude
                localPhase += twoPiOverRate
                if localPhase > 2 * Double.pi { localPhase -= 2 * Double.pi }

                for buffer in buffers {
                    let ptr = UnsafeMutableBufferPointer<Float>(buffer)
                    if frame < ptr.count { ptr[frame] = value }
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
        source = node
        try engine.start()
    }

    public func on() { gate.pointee = 1 }
    public func off() { gate.pointee = 0 }

    public func stop() {
        gate.pointee = 0
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
    }
}
