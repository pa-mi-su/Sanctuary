//
//  ContentView.swift
//  Sanctuary
//
//  Created by PMS on 3/3/26.
//

import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment

    var body: some View {
        AppShellView(environment: environment)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(environment: .local())
    }
}
