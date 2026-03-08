import Foundation

/// Simple performance measurement utility.
public class SimpleProfiler {
    private var totalTime: Double = 0
    private var startTime: DispatchTime?
    private let name: String

    public init(name: String = "Profiler") {
        self.name = name
    }

    public func reset() {
        totalTime = 0
        startTime = nil
    }

    public func before() {
        startTime = DispatchTime.now()
    }

    public func after() {
        guard let start = startTime else { return }
        let diff = calculateDiffInMs(from: start)
        totalTime += diff
    }

    public func afterPrint(_ label: String = "Measurement") {
        guard let start = startTime else { return }
        let diff = calculateDiffInMs(from: start)
        print("[\(name)] \(label): \(String(format: "%.2f", diff)) ms")
        totalTime += diff
    }

    public func printTotalTime() {
        print("[\(name)] Total Time: \(String(format: "%.2f", totalTime)) ms")
    }

    private func calculateDiffInMs(from start: DispatchTime) -> Double {
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanoTime) / 1_000_000
    }
}
