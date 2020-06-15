import UIKit
import UIKit.UIGestureRecognizerSubclass
import AudioToolbox

class DeepPressGestureRecognizer: UIGestureRecognizer {
    
    var vibrateOnDeepPress = true
    var threshold: CGFloat = 0.75
    var hardTriggerMinTime: TimeInterval = 0.5

    var onDeepPress: (() -> Void)?

    private var deepPressed: Bool = false {
        didSet {
            if (deepPressed && deepPressed != oldValue) {
                onDeepPress?()
            }
        }
    }

    private var deepPressedAt: TimeInterval = 0
    private var k_PeakSoundID: UInt32 = 1519
    private var hardAction: Selector?
    private var target: AnyObject?

    required init(target: AnyObject?, action: Selector, hardAction: Selector? = nil, threshold: CGFloat = 0.75) {
        self.target = target
        self.hardAction = hardAction
        self.threshold = threshold

        super.init(target: target, action: action)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            handle(touch: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            handle(touch: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = deepPressed ? UIGestureRecognizer.State.ended : UIGestureRecognizer.State.failed
        deepPressed = false
    }

    private func handle(touch: UITouch) {
        guard let _ = view, touch.force != 0 && touch.maximumPossibleForce != 0 else {
            return
        }

        let forcePercentage = (touch.force / touch.maximumPossibleForce)
        let currentTime = Date.timeIntervalSinceReferenceDate

        if !deepPressed && forcePercentage >= threshold {
            state = UIGestureRecognizer.State.began

            if vibrateOnDeepPress {
                AudioServicesPlaySystemSound(k_PeakSoundID)
            }

            deepPressedAt = Date.timeIntervalSinceReferenceDate
            deepPressed = true

        } else if deepPressed && forcePercentage <= 0 {
            endGesture()

        } else if deepPressed && currentTime - deepPressedAt > hardTriggerMinTime && forcePercentage == 1.0 {
            endGesture()

            if vibrateOnDeepPress {
                AudioServicesPlaySystemSound(k_PeakSoundID)
            }

            //fire hard press
            if let hardAction = self.hardAction, let target = self.target {
                _ = target.perform(hardAction, with: self)
            }
        }
    }

    func endGesture() {
        state = UIGestureRecognizer.State.ended
        deepPressed = false
    }
}
