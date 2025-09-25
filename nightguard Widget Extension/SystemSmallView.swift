//
//  Created by Dirk Hermanns on 23.05.2025.
//  Copyright © 2025 private. All rights reserved.
//
import SwiftUI
import WidgetKit

struct SystemSmallView: View {
    var entry: NightscoutDataEntry

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Image("WidgetImageBlack") // Custom owl logo
                        .resizable()
                        .aspectRatio(contentMode: ContentMode.fit)
                        .frame(width: 30, height: 30)
                        .padding(.top, 5)
                    Spacer()
                }
                Spacer()
            }
                
            
            VStack {
                // Header with time
                HStack {
                    Spacer()
                    Text(entry.entryDate, style: .time)
                        .foregroundColor(.white)
                        .font(.caption2)
                }

                // Central glucose value
                if let latest = entry.lastBGValues.first {
                    Text("\(String(latest.value))")
                        .foregroundColor(Color(entry.sgvColor))
                        .font(.system(size: 60, weight: .bold))
                        .frame(height: 50)
                } else {
                    Text("---")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.gray)
                }

                // Current delta and arrow
                if let latest = entry.lastBGValues.first {
                        Text("\(latest.delta) \(latest.arrow)")
                            .foregroundColor(Color(entry.sgvColor))
                            .font(.caption)
                }

                Divider()
                    .background(Color.white)

                // Two previous entries
                if entry.lastBGValues.count > 1 {
                    ForEach(Array(entry.lastBGValues.dropFirst()), id: \.self.id) { bgEntry in
                        HStack {
                            Text("+\(calculateAgeInMinutes(from:NSNumber(value: Date.now.timeIntervalSince1970 * 1000 + bgEntry.timestamp - (entry.lastBGValues.first?.timestamp ?? 0))))m")
                                .foregroundColor(Color(entry.sgvColor))
                                .font(.caption2)
                            Text("\(String(bgEntry.value)) \(bgEntry.delta) \(bgEntry.arrow)")
                                .foregroundColor(Color(entry.sgvColor))
                                .font(.caption2)
                        }
                    }
                }

                // Optional error message
                if !entry.errorMessage.isEmpty {
                    Text(entry.errorMessage)
                        .font(.system(size: 6))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
            }
        }
    }

    // Helper: Time difference in minutes
    func calculateAgeInMinutes(from timestamp: NSNumber) -> Int {
        let timeDiff = Date().timeIntervalSince1970 - (timestamp.doubleValue / 1000)
        return Int(timeDiff / 60)
    }

    // Helper: Match string arrow to SF Symbol
    func symbolForArrow(_ arrow: String) -> String {
        switch arrow {
        case "DoubleUp": return "arrow.up.to.line"
        case "SingleUp": return "arrow.up"
        case "FortyFiveUp": return "arrow.up.right"
        case "Flat": return "arrow.right"
        case "FortyFiveDown": return "arrow.down.right"
        case "SingleDown": return "arrow.down"
        case "DoubleDown": return "arrow.down.to.line"
        default: return "minus"
        }
    }
}
