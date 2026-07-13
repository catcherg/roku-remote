import SwiftUI
import RokuKit

/// Phase 0 placeholder. Replaced by the real app shell in Phase 2.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "av.remote")
                .font(.system(size: 48))
            Text("Clicker")
                .font(.title.bold())
            Text("RokuKit v\(RokuKit.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
