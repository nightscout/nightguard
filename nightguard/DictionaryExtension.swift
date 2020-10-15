//
//  DictionaryExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 12.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation

extension Dictionary where Value: Equatable {
    func key(from value: Value) -> Key? {
        return self.first(where: { $0.value == value })?.key
    }
}
