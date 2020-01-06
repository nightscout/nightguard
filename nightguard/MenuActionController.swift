//
//  ActionController.swift
//  nightguard
//
//  Created by Florian Preknya on 4/20/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import XLActionController

public struct MenuActionData {
    
    public fileprivate(set) var title: String?
    public fileprivate(set) var subtitle: String?
    public fileprivate(set) var image: UIImage?
    
    public init(title: String) {
        self.title = title
    }
    
    public init(title: String, subtitle: String) {
        self.init(title: title)
        self.subtitle = subtitle
    }
    
    public init(title: String, subtitle: String, image: UIImage) {
        self.init(title: title, subtitle: subtitle)
        self.image = image
    }
    
    public init(title: String, image: UIImage) {
        self.init(title: title)
        self.image = image
    }
}

class MenuActionController: ActionController<MenuActionCell, MenuActionData, UICollectionReusableView, Void, UICollectionReusableView, Void> {
    
    fileprivate lazy var blurView: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        return blurView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        backgroundView.backgroundColor = .clear
        backgroundView.addSubview(blurView)
        
        cancelView?.frame.origin.y = view.bounds.size.height // Starts hidden below screen
        cancelView?.layer.shadowColor = UIColor.black.cgColor
        cancelView?.layer.shadowOffset = CGSize( width: 0, height: -4)
        cancelView?.layer.shadowRadius = 2
        cancelView?.layer.shadowOpacity = 0.8
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        blurView.frame = backgroundView.bounds
    }
    
    override init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        settings.behavior.bounces = true
        settings.behavior.scrollEnabled = true
        settings.cancelView.showCancel = true
        settings.animation.scale = nil
        settings.animation.present.springVelocity = 0.0
        settings.cancelView.hideCollectionViewBehindCancelView = false
        
        cellSpec = .nibFile(nibName: "MenuActionCell", bundle: Bundle(for: MenuActionCell.self), height: { _ in 70 })
        
        onConfigureCellForAction = { [weak self] cell, action, indexPath in
            cell.setup(action.data?.title, detail: action.data?.subtitle, image: action.data?.image)
            cell.separatorView?.isHidden = indexPath.item == (self?.collectionView.numberOfItems(inSection: indexPath.section))! - 1
            cell.separatorView?.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
            cell.alpha = action.enabled ? 1.0 : 0.5
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        super.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
        cancelView?.frame.origin.y = view.bounds.size.height + 10
    }
    
    override func onWillPresentView() {
        cancelView?.frame.origin.y = view.bounds.size.height
    }
}
