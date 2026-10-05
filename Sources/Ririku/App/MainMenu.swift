import AppKit

/// The app's menus, shown in the menu bar while Ririku is active with its Dock icon on. Even without the Dock icon
/// they provide the standard shortcuts, such as Copy, Paste, and Close Window, in Setup.
@MainActor
enum MainMenu {
    static func make(_ model: AppModel, target: AnyObject, about: Selector, setup: Selector) -> NSMenu {
        let app = NSMenu()
        app.addItem(item(model.t("About Ririku"), about, target: target))
        app.addItem(.separator())
        app.addItem(item(model.t("Setup…"), setup, ",", target: target))
        app.addItem(.separator())
        app.addItem(item(model.t("Hide Ririku"), #selector(NSApplication.hide(_:)), "h"))
        app.addItem(item(model.t("Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        app.addItem(item(model.t("Show All"), #selector(NSApplication.unhideAllApplications(_:))))
        app.addItem(.separator())
        app.addItem(item(model.t("Quit Ririku"), #selector(NSApplication.terminate(_:)), "q"))

        let edit = NSMenu(title: model.t("Edit"))
        edit.addItem(item(model.t("Undo"), Selector(("undo:")), "z"))
        edit.addItem(item(model.t("Redo"), Selector(("redo:")), "z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(item(model.t("Cut"), #selector(NSText.cut(_:)), "x"))
        edit.addItem(item(model.t("Copy"), #selector(NSText.copy(_:)), "c"))
        edit.addItem(item(model.t("Paste"), #selector(NSText.paste(_:)), "v"))
        edit.addItem(item(model.t("Select All"), #selector(NSText.selectAll(_:)), "a"))

        let window = NSMenu(title: model.t("Window"))
        window.addItem(item(model.t("Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        window.addItem(item(model.t("Close"), #selector(NSWindow.performClose(_:)), "w"))

        let main = NSMenu()
        for (title, menu) in [("Ririku", app), (edit.title, edit), (window.title, window)] {
            let holder = main.addItem(withTitle: title, action: nil, keyEquivalent: "")
            holder.submenu = menu
        }
        NSApp.windowsMenu = window
        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "",
                             _ modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        return item
    }
}
