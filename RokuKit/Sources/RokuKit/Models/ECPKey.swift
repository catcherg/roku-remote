/// Every key accepted by `POST /keypress/{key}` (and keydown/keyup).
/// Raw values are the exact ECP strings — see ROKU_REMOTE_PROJECT_ROADMAP.md §1.1.
public enum ECPKey: String, CaseIterable, Codable, Sendable {
    case home = "Home"
    case rev = "Rev"
    case fwd = "Fwd"
    case play = "Play"
    case select = "Select"
    case left = "Left"
    case right = "Right"
    case up = "Up"
    case down = "Down"
    case back = "Back"
    case instantReplay = "InstantReplay"
    case info = "Info"
    case backspace = "Backspace"
    case search = "Search"
    case enter = "Enter"
    case volumeUp = "VolumeUp"
    case volumeDown = "VolumeDown"
    case volumeMute = "VolumeMute"
    case powerOff = "PowerOff"
    case powerOn = "PowerOn"
    case power = "Power"
    case channelUp = "ChannelUp"
    case channelDown = "ChannelDown"
    case inputTuner = "InputTuner"
    case inputHDMI1 = "InputHDMI1"
    case inputHDMI2 = "InputHDMI2"
    case inputHDMI3 = "InputHDMI3"
    case inputHDMI4 = "InputHDMI4"
    case inputAV1 = "InputAV1"
    case findRemote = "FindRemote"

    /// Keys that only function on Roku TVs (`is-tv == true`), not sticks/boxes.
    /// UI must hide or disable these for non-TV devices.
    public var requiresTV: Bool {
        switch self {
        case .volumeUp, .volumeDown, .volumeMute,
             .powerOff, .powerOn, .power,
             .channelUp, .channelDown,
             .inputTuner, .inputHDMI1, .inputHDMI2, .inputHDMI3, .inputHDMI4, .inputAV1:
            return true
        default:
            return false
        }
    }
}
