//
//  UIView+Extensions.swift
//  nightguard
//
//  Created by Florian Preknya on 6/14/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit

extension UIView {
    func pin(to view: UIView) {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topAnchor.constraint(equalTo: view.topAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
    }
}
