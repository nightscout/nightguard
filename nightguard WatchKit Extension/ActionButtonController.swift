//
//  ActionController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 05.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

class ActionButtonController: WKHostingController<ActionButtonView> {
    override var body: ActionButtonView {
        return ActionButtonView()
    }
}

struct ActionButtonController_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
