import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var message: String?
    @State private var restoring = false
    private let subscription = SubscriptionService.shared
    private let reminder = Reminder.shared
    private let journal = Journal.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if subscription.isPro {
                        Label("Inkling Pro", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.ink)
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Inkling Pro", systemImage: "seal")
                        }
                        .accessibilityIdentifier("settings.pro")
                    }
                }
                Section {
                    Toggle("Daily Reminder", isOn: Binding(
                        get: { reminder.isOn },
                        set: { on in
                            if on {
                                Task {
                                    if await !reminder.turnOn() {
                                        message = String(localized: "Notifications are off for Inkling. Turn them on in the Settings app.")
                                    }
                                }
                            } else {
                                reminder.turnOff()
                            }
                        }
                    ))
                    .accessibilityIdentifier("settings.reminder")
                    if reminder.isOn {
                        DatePicker("Time", selection: Binding(get: { reminder.date }, set: { reminder.setTime($0) }), displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    if subscription.isPro {
                        ShareLink(item: Book(), preview: SharePreview("Inkling")) {
                            Label("Export Book", systemImage: "book.closed")
                        }
                        ShareLink(item: journal.export(library: .bundled)) {
                            Label("Export Text", systemImage: "doc.plaintext")
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Export Book", systemImage: "book.closed")
                        }
                        .accessibilityIdentifier("settings.book")
                    }
                }
                Section {
                    Button { openURL(Links.writeReview) } label: { Label("Rate Inkling", systemImage: "star") }
                        .simultaneousGesture(TapGesture().onEnded { ReviewPrompt().markOpenedStore() })
                    Button { openURL(Links.feedback) } label: { Label("Send Feedback", systemImage: "envelope") }
                    if !subscription.isPro {
                        Button { restore() } label: { Label("Restore Purchases", systemImage: "arrow.clockwise") }
                            .disabled(restoring)
                    }
                }
                Section {
                    Button { openURL(Links.privacy) } label: { Label("Privacy Policy", systemImage: "hand.raised") }
                    Button { openURL(Links.terms) } label: { Label("Terms of Use", systemImage: "doc.text") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .foregroundStyle(Theme.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings").font(Theme.serif(.headline, weight: .semibold)).foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {}
        }
    }

    private func restore() {
        restoring = true
        Task {
            let result = await subscription.restore()
            restoring = false
            switch result {
            case .found: message = String(localized: "Inkling Pro is restored")
            case .cancelled: break
            case .notFound: message = String(localized: "No purchase found on this Apple Account")
            case .failed: message = String(localized: "The App Store could not be reached. Try again when you are online.")
            }
        }
    }
}
