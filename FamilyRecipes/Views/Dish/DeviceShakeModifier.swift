import SwiftUI
import UIKit

// The notification we will send when a shake gesture is detected
extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("MyDeviceDidShakeNotification")
}

// Override UIWindow's motionEnded to post a notification on shake
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

// The ViewModifier that listens for the notification and triggers the action
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

// Convenient extension on View to use .onShake(perform: action)
extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
