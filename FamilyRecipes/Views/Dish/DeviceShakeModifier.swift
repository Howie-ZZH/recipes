import SwiftUI
import UIKit
import CoreMotion

// Notification sent when shake gesture is detected
extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("MyDeviceDidShakeNotification")
}

// Override UIApplication to catch motionShake events (e.g., Xcode Simulator shake gesture)
extension UIApplication {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// Manager using CMMotionManager for physical device accelerometer shake detection
final class ShakeMotionManager {
    static let shared = ShakeMotionManager()
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var lastShakeTime: Date = .distantPast
    
    init() {
        motionQueue.name = "com.familyrecipes.motionQueue"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .utility
    }
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1 // 10Hz is lightweight and responsive
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            // Shake threshold (~2.2g acceleration)
            if acceleration > 2.2 {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > 1.2 { // 1.2s debounce
                    self.lastShakeTime = now
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .deviceDidShake, object: nil)
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
}

// ViewModifier that monitors shake events from NotificationCenter
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                ShakeMotionManager.shared.startMonitoring()
            }
            .onDisappear {
                ShakeMotionManager.shared.stopMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

