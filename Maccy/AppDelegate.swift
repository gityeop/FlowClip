// Updated AppDelegate.swift with queuePasteLifo and UI toggle

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var queuePasteLifo: Bool = false // Default is LIFO
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup for LIFO toggle in UI
    }
    
    func nextToPaste() -> AnyObject? {
        // Update this behavior based on queuePasteLifo
    }
}