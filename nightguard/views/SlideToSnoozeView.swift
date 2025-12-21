//
//  SlideToSnoozeView.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.04.19.
//  Based on the work of Martin Lee:
//  https://github.com/lemanhtien/MTSlideToOpen
//
//  This snipped is released under the MIT 2019 Licence.
//
import UIKit

@objc public protocol SlideToSnoozeDelegate {
    func slideToSnoozeDelegateDidFinish(_ sender: SlideToSnoozeView)
}

public class SlideToSnoozeView: UIView {
    
    // MARK: All Views
    public let textLabel: UILabel = {
        let label = UILabel.init()
        return label
    }()
    public let thumbnailImageView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = true
        view.contentMode = .center
        return view
    }()
    public let sliderHolderView: UIView = {
        let view = UIView()
        return view
    }()
    public let draggedView: UIView = {
        let view = UIView()
        return view
    }()
    public let view: UIView = {
        let view = UIView()
        return view
    }()
    
    // MARK: Public properties
    public weak var delegate: SlideToSnoozeDelegate?
    public var animationVelocity: Double = 0.2
    public var sliderViewTopDistance: CGFloat = 0.0
    public var thumbnailViewLeadingDistance: CGFloat = 0.0
    public var textLabelLeadingDistance: CGFloat = 0
    public var isEnabled:Bool = true {
        didSet {
            animationChangedEnabledBlock?(isEnabled)
        }
    }
    public var animationChangedEnabledBlock:((Bool) -> Void)?
    
    // MARK: Private Properties
    private var sliderCornerRadious: CGFloat = 4.0
    private var defaultLabelText: String = "Swipe to Snooze"
    private var leadingThumbnailViewConstraint: NSLayoutConstraint?
    private var leadingTextLabelConstraint: NSLayoutConstraint?
    private var topSliderConstraint: NSLayoutConstraint?
    private var xPositionInThumbnailView: CGFloat = 0
    private var xEndingPoint: CGFloat {
        get {
            return (self.view.frame.maxX - thumbnailImageView.bounds.height)
        }
    }
    private var isFinished: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setupView()
    }
    
    private func setupView() {
        thumbnailImageView.image = #imageLiteral(resourceName: "SlideArrow").withRenderingMode(.alwaysTemplate)
        thumbnailImageView.tintColor = UIColor.App.Preferences.detailText
        
        self.addSubview(view)
        // add a tap gesture recognizer to let the user now that he has to slide instead of tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(signalThatASlideInsteadOfATapIsNeededToSnooze(sender:)))
        view.addGestureRecognizer(tapGesture)
        view.addSubview(thumbnailImageView)
        view.addSubview(sliderHolderView)
        view.addSubview(draggedView)
        sliderHolderView.addSubview(textLabel)
        view.bringSubviewToFront(self.thumbnailImageView)
        setupConstraint()
        setStyle()
        // Add pan gesture
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
        panGestureRecognizer.minimumNumberOfTouches = 1
        thumbnailImageView.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc func signalThatASlideInsteadOfATapIsNeededToSnooze(sender: UITapGestureRecognizer) {
        print("Tap")
        UIView.animate(withDuration: animationVelocity, animations: {
                self.leadingThumbnailViewConstraint?.constant = 50
                self.textLabel.alpha = 1
                self.layoutIfNeeded()
            }, completion: { _ in
                UIView.animate(withDuration: self.animationVelocity) {
                    self.leadingThumbnailViewConstraint?.constant = self.thumbnailViewLeadingDistance
                    self.textLabel.alpha = 1
                    self.layoutIfNeeded()
                }
            })
    }
    
    private func setupConstraint() {
        view.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        sliderHolderView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        draggedView.translatesAutoresizingMaskIntoConstraints = false
        // Setup for view
        view.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        // Setup for circle View
        leadingThumbnailViewConstraint = thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        leadingThumbnailViewConstraint?.isActive = true
        thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        thumbnailImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor).isActive = true
        // Setup for slider holder view
        topSliderConstraint = sliderHolderView.topAnchor.constraint(equalTo: view.topAnchor, constant: sliderViewTopDistance)
        topSliderConstraint?.isActive = true
        sliderHolderView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        sliderHolderView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        sliderHolderView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        // Setup for textLabel
        textLabel.topAnchor.constraint(equalTo: sliderHolderView.topAnchor).isActive = true
        textLabel.centerYAnchor.constraint(equalTo: sliderHolderView.centerYAnchor).isActive = true
        leadingTextLabelConstraint = textLabel.leadingAnchor.constraint(equalTo: sliderHolderView.leadingAnchor, constant: textLabelLeadingDistance)
        leadingTextLabelConstraint?.isActive = true
        textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: CGFloat(-8)).isActive = true
        // Setup for Dragged View
        draggedView.leadingAnchor.constraint(equalTo: sliderHolderView.leadingAnchor).isActive = true
        draggedView.topAnchor.constraint(equalTo: sliderHolderView.topAnchor).isActive = true
        draggedView.bottomAnchor.constraint(equalTo: sliderHolderView.bottomAnchor).isActive = true
        draggedView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor).isActive = true
    }
    
    private func setStyle() {
        thumbnailImageView.backgroundColor = UIColor.App.Preferences.selectedRowBackground.withAlphaComponent(0.6)
        thumbnailImageView.layer.cornerRadius = sliderCornerRadious

        draggedView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        draggedView.layer.cornerRadius = sliderCornerRadious
        
        sliderHolderView.backgroundColor = UIColor.App.Preferences.background
        sliderHolderView.layer.cornerRadius = sliderCornerRadious
        
        textLabel.text = defaultLabelText
        textLabel.numberOfLines = 2
        textLabel.font = UIFont.systemFont(ofSize: DeviceSize().isSmall ? 24 : 27)
        textLabel.textColor = UIColor.App.Preferences.text
        textLabel.textAlignment = .center
    }
    
    private func isTapOnThumbnailViewWithPoint(_ point: CGPoint) -> Bool{
        return self.thumbnailImageView.frame.contains(point)
    }
    
    private func updateThumbnailViewLeadingPosition(_ x: CGFloat) {
        leadingThumbnailViewConstraint?.constant = x
        setNeedsLayout()
    }
    
    // MARK: UIPanGestureRecognizer
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        if !isEnabled {
            return
        }
        let translatedPoint = sender.translation(in: view).x
        switch sender.state {
        case .began:
            break
        case .changed:
            if translatedPoint >= xEndingPoint {
                updateThumbnailViewLeadingPosition(xEndingPoint)
                return
            }
            if translatedPoint <= thumbnailViewLeadingDistance {
                textLabel.alpha = 1
                updateThumbnailViewLeadingPosition(thumbnailViewLeadingDistance)
                return
            }
            updateThumbnailViewLeadingPosition(translatedPoint)
            textLabel.alpha = (xEndingPoint - translatedPoint) / xEndingPoint
            break
        case .ended:
            // add some tolerance so that the slider doesn't need to be pushed to the very end
            // of the sliding area
            if translatedPoint >= xEndingPoint - 50 {
                textLabel.alpha = 0
                updateThumbnailViewLeadingPosition(xEndingPoint)
                delegate?.slideToSnoozeDelegateDidFinish(self)
            }
            if translatedPoint <= thumbnailViewLeadingDistance {
                textLabel.alpha = 1
                updateThumbnailViewLeadingPosition(thumbnailViewLeadingDistance)
                return
            }
            letButtonReturnToStartPosition()
            break
        default:
            break
        }
    }
    
    private func letButtonReturnToStartPosition() {
        UIView.animate(withDuration: animationVelocity) {
            self.leadingThumbnailViewConstraint?.constant = self.thumbnailViewLeadingDistance
            self.textLabel.alpha = 1
            self.layoutIfNeeded()
        }
    }

    // Others
    public func resetStateWithAnimation(_ animated: Bool) {
        let action = {
            self.leadingThumbnailViewConstraint?.constant = 0
            self.textLabel.alpha = 1
            self.layoutIfNeeded()
            //
            self.isFinished = false
        }
        if animated {
            UIView.animate(withDuration: animationVelocity) {
                action()
            }
        } else {
            action()
        }
    }
    
    public func setAttributedTitle(title : NSMutableAttributedString) {
        self.textLabel.attributedText = title
    }
}
