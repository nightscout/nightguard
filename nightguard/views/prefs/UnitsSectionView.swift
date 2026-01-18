//
//  UnitsSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct UnitsSectionView: View {
    @Binding var manuallySetUnits: Bool
    @Binding var selectedUnits: Units
    
    var onUnitsChanged: () -> Void
    
    var body: some View {
        Section(
            footer: Text("If enabled, you will override your Units-Setting of your nightscout backend. Usually you can disable this. Nightguard will determine the correct Units on its own.")
                .font(.footnote)
        ) {
            Toggle("Manually set Units", isOn: $manuallySetUnits)
                .onChange(of: manuallySetUnits) { newValue in
                    UserDefaultsRepository.manuallySetUnits.value = newValue
                    onUnitsChanged()
                }

            if manuallySetUnits {
                Picker("Use the following Units", selection: $selectedUnits) {
                    ForEach([Units.mgdl, Units.mmol], id: \.self) { unit in
                        Text(unit.description).tag(unit)
                    }
                }
                .onChange(of: selectedUnits) { newValue in
                    UserDefaultsRepository.units.value = newValue
                    onUnitsChanged()
                }
            }
        }
    }
}
