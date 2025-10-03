//
//  SiplyWidgetBundle.swift
//  SiplyWidget
//
//  Created by Jonas Hoppe on 03.10.25.
//

import WidgetKit
import SwiftUI

@main
struct SiplyWidgetBundle: WidgetBundle {
    var body: some Widget {
        SiplyWidget()
        SiplyWidgetControl()
        SiplyWidgetLiveActivity()
    }
}
