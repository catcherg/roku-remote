import Foundation

/// XML fixtures modeled on real ECP payloads (roadmap Phase 1 task 7:
/// one Roku TV, one streaming stick).
enum Fixtures {
    /// TCL Roku TV — `is-tv` true, has power/volume.
    static let tvDeviceInfoXML = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <device-info>
        <udn>29380000-7000-1000-8000-d831345e9080</udn>
        <serial-number>YN00H5555555</serial-number>
        <device-id>S055555555555</device-id>
        <vendor-name>TCL</vendor-name>
        <model-name>65S455</model-name>
        <model-number>8365X</model-number>
        <model-region>US</model-region>
        <is-tv>true</is-tv>
        <is-stick>false</is-stick>
        <screen-size>65</screen-size>
        <user-device-name>Living Room TV</user-device-name>
        <friendly-device-name>Living Room TV</friendly-device-name>
        <default-device-name>TCL•Roku TV - YN00H5555555</default-device-name>
        <power-mode>PowerOn</power-mode>
        <network-type>wifi</network-type>
        <software-version>12.5.0</software-version>
    </device-info>
    """

    /// Roku Express stick — `is-tv` false, no user-assigned name.
    static let stickDeviceInfoXML = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <device-info>
        <udn>015e5108-9000-1000-8000-d831345e9080</udn>
        <serial-number>X01000AAAAAA</serial-number>
        <vendor-name>Roku</vendor-name>
        <model-name>Roku Express</model-name>
        <model-number>3930X</model-number>
        <is-tv>false</is-tv>
        <is-stick>true</is-stick>
        <default-device-name>Roku Express - X01000AAAAAA</default-device-name>
        <power-mode>PowerOn</power-mode>
        <software-version>12.5.0</software-version>
    </device-info>
    """

    static let appsXML = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <apps>
        <app id="12" type="appl" version="5.1.60">Netflix</app>
        <app id="837" type="appl" version="1.0.80000286">YouTube</app>
        <app id="2285" type="appl" version="6.65.0">Hulu</app>
        <app id="31012" type="menu" version="1.9.60">Movie Store and TV Store</app>
    </apps>
    """

    static let ssdpResponse = """
    HTTP/1.1 200 OK\r
    Cache-Control: max-age=3600\r
    ST: roku:ecp\r
    Location: http://192.168.1.134:8060/\r
    USN: uuid:roku:ecp:YN00H5555555\r
    \r

    """

    static var tvDeviceInfoData: Data { Data(tvDeviceInfoXML.utf8) }
    static var stickDeviceInfoData: Data { Data(stickDeviceInfoXML.utf8) }
    static var appsData: Data { Data(appsXML.utf8) }
}
