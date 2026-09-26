import Foundation
import Darwin

@main
struct StressEngine {
    static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1048576 : -1
    }
    static func main() throws {
        let args = CommandLine.arguments
        let engine = UpscaleEngine(modelDirectory: URL(fileURLWithPath: args[1]))
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 2
        let lock = NSLock()
        var failures = 0
        for index in 1...50 {
            queue.addOperation {
                autoreleasepool {
                    let output = args[3] + "-\(index).jpg"
                    do {
                        try engine.upscale(path: args[2], output: output, modelName: "real-cugan-v1",
                                           scale: 2, denoise: 0, cancellation: UpscaleCancellation())
                        try FileManager.default.removeItem(atPath: output)
                    } catch {
                        lock.lock(); failures += 1; lock.unlock()
                        print("failure: \(error)")
                    }
                }
                if index % 5 == 0 { print("completed=\(index) residentMB=\(residentMB())") }
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        precondition(failures == 0)
        print("Completed 50 jobs, concurrency 2; residentMB=\(residentMB())")
    }
}
