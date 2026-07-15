import Foundation

/// Parsed `GET /query/device-info` response. Only the fields the app needs.
public struct DeviceInfo: Equatable, Sendable {
    public let serialNumber: String
    public let modelName: String
    public let friendlyName: String
    public let isTV: Bool
    public let powerMode: String?

    public init(serialNumber: String, modelName: String, friendlyName: String,
                isTV: Bool, powerMode: String?) {
        self.serialNumber = serialNumber
        self.modelName = modelName
        self.friendlyName = friendlyName
        self.isTV = isTV
        self.powerMode = powerMode
    }

    /// Parse device-info XML. Throws `ECPError.decodingFailed` when the payload
    /// is not a Roku device-info document (no serial number).
    public static func parse(_ data: Data) throws -> DeviceInfo {
        let values = XMLDictionaryParser.parse(data)
        guard let serial = values["serial-number"], !serial.isEmpty else {
            throw ECPError.decodingFailed
        }
        let name = values["friendly-device-name"]
            ?? values["user-device-name"]
            ?? values["default-device-name"]
            ?? values["model-name"]
            ?? "Roku"
        return DeviceInfo(
            serialNumber: serial,
            modelName: values["model-name"] ?? "",
            friendlyName: name,
            isTV: values["is-tv"] == "true",
            powerMode: values["power-mode"]
        )
    }

    /// Convert to a `RokuDevice` once we know the IP it answered on.
    public func device(ip: String) -> RokuDevice {
        RokuDevice(serialNumber: serialNumber, name: friendlyName, ip: ip,
                   isTV: isTV, model: modelName)
    }
}

/// Flattens simple `<parent><leaf>text</leaf>...</parent>` XML into a dictionary.
/// First occurrence of each element wins (device-info elements are unique anyway).
final class XMLDictionaryParser: NSObject, XMLParserDelegate {
    private var currentText = ""
    private var values: [String: String] = [:]

    static func parse(_ data: Data) -> [String: String] {
        let delegate = XMLDictionaryParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.values
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && values[elementName] == nil {
            values[elementName] = text
        }
        currentText = ""
    }
}
