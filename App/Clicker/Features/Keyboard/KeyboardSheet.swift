import SwiftUI
import RokuKit

/// "Type with your phone" (Phase 2 task 6). Diffs the text field against its
/// previous value on every change: deletions become Backspace keypresses,
/// additions are sent per-character via typeText (Lit_ encoding in RokuKit).
struct KeyboardSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var previous = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Everything you type is sent to the Roku")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Type here…", text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onChange(of: text) { newValue in
                    sendDiff(from: previous, to: newValue)
                    previous = newValue
                }
                .onSubmit {
                    app.send(.enter)
                    dismiss()
                }
                .submitLabel(.send)
                .padding(.horizontal)

            Spacer()
        }
        .onAppear { focused = true }
    }

    /// Common-prefix diff: handles typing, autocomplete replacing a word,
    /// and deletions — without re-sending the whole field.
    private func sendDiff(from old: String, to new: String) {
        let oldChars = Array(old)
        let newChars = Array(new)
        var prefix = 0
        while prefix < oldChars.count && prefix < newChars.count
                && oldChars[prefix] == newChars[prefix] {
            prefix += 1
        }
        let deletions = oldChars.count - prefix
        if deletions > 0 {
            app.sendBackspace(count: deletions)
        }
        if prefix < newChars.count {
            app.typeText(String(newChars[prefix...]))
        }
    }
}
