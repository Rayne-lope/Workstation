import Foundation

public protocol TerminalLaunching: Sendable {
    func openTerminal(at projectURL: URL, command: String?) throws
}
