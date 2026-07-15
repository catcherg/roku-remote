import Foundation

/// One installed channel from `GET /query/apps`.
public struct RokuApp: Identifiable, Codable, Hashable, Sendable {
    /// Channel ID used in `/launch/{id}` and `/query/icon/{id}` (e.g. Netflix = "12").
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Parses `/query/apps` XML: `<apps><app id="12" ...>Netflix</app>...</apps>`.
final class AppsXMLParser: NSObject, XMLParserDelegate {
    private var apps: [RokuApp] = []
    private var currentID: String?
    private var currentName = ""

    static func parse(_ data: Data) -> [RokuApp] {
        let delegate = AppsXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.apps
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        guard elementName == "app" else { return }
        currentID = attributeDict["id"]
        currentName = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentName += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "app", let id = currentID else { return }
        let name = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !id.isEmpty && !name.isEmpty {
            apps.append(RokuApp(id: id, name: name))
        }
        currentID = nil
    }
}
