import SwiftUI
import EventKit
import EventKitUI

struct ActionCalendarDraft: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let durationMinutes: Int
    let store: EKEventStore

    @MainActor static func prepare(title: String, startISO: String, durationMinutes: Int) async -> ActionCalendarDraft? {
        guard let start = ISO8601DateFormatter().date(from: startISO), durationMinutes > 0 else { return nil }
        let store = EKEventStore()
        if #available(iOS 17, *) {
            // EventKitUI edits/saves outside the app; no calendar-read permission.
        } else {
            guard (try? await store.requestAccess(to: .event)) == true else { return nil }
        }
        return ActionCalendarDraft(title: title, start: start, durationMinutes: durationMinutes, store: store)
    }
}

struct ActionCalendarEditor: UIViewControllerRepresentable {
    let draft: ActionCalendarDraft
    let onComplete: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let editor = EKEventEditViewController()
        editor.eventStore = draft.store
        let event = EKEvent(eventStore: draft.store)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.start.addingTimeInterval(Double(draft.durationMinutes) * 60)
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onComplete: (Bool) -> Void
        init(onComplete: @escaping (Bool) -> Void) { self.onComplete = onComplete }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onComplete(action == .saved)
        }
    }
}
