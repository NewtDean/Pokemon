//
//  Item.swift
//  Pokemon
//
//  Created by dingdaojun on 2026/6/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
