import SwiftUI
import RirikuCore

/// Today's events that have not ended, or tomorrow's. Clicking opens the Calendar app; events cannot be changed
/// here (R-WID-8).
struct CalendarWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var calendar: CalendarStore
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if calendar.access == .granted {
                if let agenda = calendar.agenda { agendaView(agenda) } else { Text(model.t("Calendar")).widgetCaption() }
            } else {
                Text(model.t("Calendar")).widgetCaption()
                PermissionPrompt(model: model, state: calendar.access,
                                 message: calendar.access == .denied ? model.t("Ririku has no access to your calendars.")
                                     : model.t("Allow access to show your events here."),
                                 pane: PrivacySettings.calendars) { calendar.requestAccessIfNeeded() }
            }
        }
        .widgetCard()
        .onAppear { calendar.start() }
        .onDisappear { calendar.stop() }
    }

    private func agendaView(_ agenda: Agenda) -> some View {
        let shown = Array(agenda.events.prefix(wide ? 3 : 1))
        let more = agenda.events.count - shown.count
        return Button { calendar.openCalendarApp() } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(agenda.day == .today ? model.t("Today") : model.t("Tomorrow")).widgetCaption()
                    Spacer(minLength: 4)
                    if more > 0 {
                        Text(model.t("%@ more", more.formatted(.number.locale(model.locale))))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                }
                if let first = shown.first {
                    if wide { ForEach(shown) { row($0) } } else { next(first) }
                } else {
                    Spacer(minLength: 0)
                    Text(model.t("No more events today")).font(.callout).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.t("Opens Calendar"))
    }

    /// The small widget: the next event with its calendar's color, title, and time.
    private func next(_ event: AgendaEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5).fill(calendar.color(of: event)).frame(width: 3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title(event)).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                Text(time(event, long: true)).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func row(_ event: AgendaEvent) -> some View {
        HStack(spacing: 8) {
            Circle().fill(calendar.color(of: event)).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(title(event)).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
            Spacer(minLength: 6)
            Text(time(event, long: false)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func title(_ event: AgendaEvent) -> String {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? model.t("Untitled event") : title
    }

    /// "All day", "Now · until 11:00", "10:00 – 11:00", or only the start time in a wide widget's row.
    private func time(_ event: AgendaEvent, long: Bool) -> String {
        if event.allDay { return model.t("All day") }
        let locale = model.timeLocale
        let end = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale).format(event.end)
        if event.isOngoing(at: Date()) { return long ? model.t("Now · until %@", end) : model.t("Now") }
        guard long else { return Date.FormatStyle(date: .omitted, time: .shortened, locale: locale).format(event.start) }
        return (event.start..<max(event.start, event.end)).formatted(Date.IntervalFormatStyle(date: .omitted, time: .shortened, locale: locale))
    }
}

/// A mirror from the Mac's camera. It turns on only when clicked in the open panel and turns off when it
/// disappears (R-WID-5).
struct CameraWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraMirror
    @State private var id = UUID()
    @Environment(\.panelPreview) private var preview

    var body: some View {
        Group {
            if camera.owner == id {
                CameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity).frame(height: WidgetCardLayout.height)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        WidgetButton(icon: "video.slash", label: model.t("Turn Off Camera"), size: 22) { camera.stop(for: id) }
                            .padding(6)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(model.t("Camera mirror"))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t("Camera")).widgetCaption()
                    if camera.access == .granted {
                        off
                    } else {
                        PermissionPrompt(model: model, state: camera.access,
                                         message: camera.access == .denied ? model.t("Ririku has no access to the camera.")
                                             : model.t("Allow access to use the camera as a mirror."),
                                         pane: PrivacySettings.camera) { camera.requestAccessIfNeeded() }
                    }
                }
                .widgetCard()
            }
        }
        .onDisappear { camera.stop(for: id) }
    }

    private var off: some View {
        Button { camera.start(for: id) } label: {
            VStack(spacing: 6) {
                Image(systemName: "web.camera").font(.system(size: 20, weight: .medium))
                    .frame(width: 42, height: 42).background(Circle().fill(.white.opacity(0.12)))
                Text(message).font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(preview)
        .accessibilityLabel(model.t("Turn On Camera"))
    }

    private var message: String {
        if preview { return model.t("The camera turns on only in the panel.") }
        switch camera.problem {
        case .noCamera: return model.t("No camera found.")
        case .stopped: return model.t("The camera stopped. Click to try again.")
        case nil: return model.t("Click to turn on the camera.")
        }
    }
}
