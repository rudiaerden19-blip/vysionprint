import Foundation

/// ESC/POS printer commands voor thermische bonprinters
struct ESCPOSCommands {
    
    // MARK: - Basic Commands
    
    /// Initialize printer
    static var initialize: Data {
        Data([0x1B, 0x40])  // ESC @
    }
    
    // MARK: - Text Formatting
    
    /// Align text center
    static var alignCenter: Data {
        Data([0x1B, 0x61, 0x01])  // ESC a 1
    }
    
    /// Align text left
    static var alignLeft: Data {
        Data([0x1B, 0x61, 0x00])  // ESC a 0
    }
    
    /// Align text right
    static var alignRight: Data {
        Data([0x1B, 0x61, 0x02])  // ESC a 2
    }
    
    /// Bold on
    static var boldOn: Data {
        Data([0x1B, 0x45, 0x01])  // ESC E 1
    }
    
    /// Bold off
    static var boldOff: Data {
        Data([0x1B, 0x45, 0x00])  // ESC E 0
    }
    
    /// Double height text
    static var doubleHeight: Data {
        Data([0x1D, 0x21, 0x01])  // GS ! 1
    }
    
    /// Double width text
    static var doubleWidth: Data {
        Data([0x1D, 0x21, 0x10])  // GS ! 16
    }
    
    /// Double height and width
    static var doubleSize: Data {
        Data([0x1D, 0x21, 0x11])  // GS ! 17
    }
    
    /// Normal size text
    static var normalSize: Data {
        Data([0x1D, 0x21, 0x00])  // GS ! 0
    }
    
    /// Underline on
    static var underlineOn: Data {
        Data([0x1B, 0x2D, 0x01])  // ESC - 1
    }
    
    /// Underline off
    static var underlineOff: Data {
        Data([0x1B, 0x2D, 0x00])  // ESC - 0
    }
    
    // MARK: - Paper Control
    
    /// Line feed
    static var lineFeed: Data {
        Data([0x0A])  // LF
    }
    
    /// Feed n lines
    static func feedLines(_ n: UInt8) -> Data {
        Data([0x1B, 0x64, n])  // ESC d n
    }
    
    /// Cut paper (full cut)
    static var cutPaper: Data {
        Data([0x1D, 0x56, 0x00])  // GS V 0
    }
    
    /// Cut paper (partial cut)
    static var partialCut: Data {
        Data([0x1D, 0x56, 0x01])  // GS V 1
    }
    
    // MARK: - Cash Drawer
    
    /// Open cash drawer (pin 2)
    static var openDrawer: Data {
        Data([0x1B, 0x70, 0x00, 0x19, 0xFA])  // ESC p 0 25 250
    }
    
    /// Open cash drawer (pin 5)
    static var openDrawerPin5: Data {
        Data([0x1B, 0x70, 0x01, 0x19, 0xFA])  // ESC p 1 25 250
    }
    
    // MARK: - Beeper
    
    /// Beep
    static var beep: Data {
        Data([0x1B, 0x42, 0x03, 0x02])  // ESC B 3 2
    }
    
    // MARK: - Special Characters
    
    /// Euro symbol (code page 858)
    static var euroSymbol: Data {
        Data([0xD5])  // €
    }
    
    /// Set code page to PC858 (Western European with Euro)
    static var codePagePC858: Data {
        Data([0x1B, 0x74, 0x13])  // ESC t 19
    }
    
    // MARK: - Helper Methods
    
    /// Create a horizontal line
    static func horizontalLine(width: Int = 32) -> Data {
        let line = String(repeating: "-", count: width) + "\n"
        return line.data(using: .ascii) ?? Data()
    }
    
    /// Format a price line with left and right alignment
    static func priceLine(left: String, right: String, width: Int = 32) -> Data {
        let padding = max(1, width - left.count - right.count)
        let line = left + String(repeating: " ", count: padding) + right + "\n"
        return line.data(using: .utf8) ?? Data()
    }
}
