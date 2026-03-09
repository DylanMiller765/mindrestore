import SwiftUI
import ConfettiSwiftUI

struct ConfettiView: View {
    @State private var counter = 0

    var body: some View {
        ZStack {}
            .confettiCannon(
                counter: $counter,
                num: 50,
                colors: [.red, .blue, .green, .yellow, .orange, .pink, .purple, .cyan, .mint],
                rainHeight: 600,
                radius: 400
            )
            .allowsHitTesting(false)
            .onAppear {
                counter += 1
            }
    }
}
