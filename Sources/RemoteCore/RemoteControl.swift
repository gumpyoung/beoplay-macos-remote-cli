import Foundation
import SwiftyJSON

public class RemoteControl {
    private var endpoint = URLComponents()
    private var notificationSession: NotificationSession?
    private var remoteAdmin = RemoteAdminControl()
    private let browser = BeoplayBrowser()
    private var _hasEndpoint = false

    public init() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

        self.endpoint.scheme = "http"
    }

    private func request(method: String,
            path: String,
            query: String? = nil,
            body: String? = nil, 
            completionData: ((Data?) -> ())? = nil, 
            _ completion: (() -> ())? = nil) {

        var urlComponents = self.endpoint
        urlComponents.path = path
        urlComponents.query = query

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = method
        request.httpBody = body?.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            completionData?(data)
            completion?()
        };

        task.resume()
    }

    public func startDiscovery(delegate: NetServiceBrowserDelegate, withTimeout: TimeInterval? = nil, next: (() -> ())? = nil) {
        browser.searchForDevices(delegate: delegate, withTimeout: withTimeout, next: next)
    }

    public func stopDiscovery() {
        browser.stop()
    }

    public func setEndpoint(host: String, port: Int, adminPort: Int = 80) {
        self.endpoint.host = host
        self.endpoint.port = port

        self.remoteAdmin.setEndpoint(host: host, port: adminPort)

        self._hasEndpoint = true
    }

    public func hasEndpoint() -> Bool {
        return self._hasEndpoint
    }

    public func getSources(_ completion: @escaping ([BeoplaySource]) -> ()) {
        func completionData(data: Data?) {
            var sources = [BeoplaySource]()

            if data != nil, let json = try? JSON(data: data!) {
                for (_, source) in json["sources"] {
                    let source = BeoplaySource(
                        id: source[0].stringValue,
                        sourceType: source[1]["sourceType"]["type"].stringValue,
                        category: source[1]["category"].stringValue,
                        friendlyName: source[1]["friendlyName"].stringValue,
                        borrowed: source[1]["borrowed"].boolValue,
                        productJid: source[1]["product"]["jid"].stringValue,
                        productFriendlyName: source[1]["product"]["friendlyName"].stringValue
                    )
                    sources.append(source)
                }
            }

           completion(sources)
        }

        request(method: "GET", path: "/BeoZone/Zone/Sources", completionData: completionData)
    }

    public func getEnabledSources(_ completion: @escaping ([BeoplaySource]) -> ()) {
        self.remoteAdmin.getEnabledControlledSourceIds { (enabledSourceIds: [String]) -> () in
            self.getSources { (sources: [BeoplaySource]) -> () in
                var result = [BeoplaySource]()
                if enabledSourceIds.isEmpty {
                    // fallback fx for Beosound Moment
                    result = sources
                } else {
                    for id in enabledSourceIds {
                        let isBorrowed = id.contains(":")
                        for source in sources {
                            let sourceId = isBorrowed ? id : "\(id):\(source.productJid)"
                            if sourceId == source.id && isBorrowed == source.borrowed {
                                result.append(source)
                            }
                        }
                    }
                }

                completion(result)
            }
        }
    }

    public func setSource(id: String, _ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/ActiveSources", body: "{\"primaryExperience\":{\"source\":{\"id\":\"\(id)\"}}}", completion)
    }

    public func play(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Play", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Play/Release");
    }

    public func pause(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Pause", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Pause/Release");
    }

    public func stop(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Stop", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Stop/Release");
    }

    public func forward(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Forward", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Forward/Release");
    }

    public func backward(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Backward", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Backward/Release");
    }

    public func getVolume(_ completion: @escaping (Int?) -> ()) {
        func getVolumeFromJSON(_ data: Data?) -> Int? {
            var volume: Int?
            if data != nil, let json = try? JSON(data: data!) {
                volume = Int(json["speaker"]["level"].stringValue)
            }
            return volume
        }

        func completionData(data: Data?) {
            let vol = getVolumeFromJSON(data)
            completion(vol)
        }

        request(method: "GET", path: "/BeoZone/Zone/Sound/Volume/Speaker/", completionData: completionData)
    }

    public func setVolume(volume: Int, _ completion: @escaping () -> () = {}) {
        var vol = max(0, volume)
        vol = min(100, vol)
        request(method: "PUT", path: "/BeoZone/Zone/Sound/Volume/Speaker/Level", body: "{\"level\":\(vol)}", completion)
    }

    public func adjustVolume(delta: Int, _ completion: @escaping () -> () = {}) {
        self.getVolume { volume in
            guard let vol = volume else {
                return
            }
            self.setVolume(volume: vol + delta, completion)
        }
    }

    public func startNotifications() {
        var urlComponents = self.endpoint
        urlComponents.path = "/BeoNotify/Notifications"

        self.notificationSession = NotificationSession(url: urlComponents.url!, processor: NotificationBridge())
        self.notificationSession?.start()
    }

    public func stopNotifications() {
        self.notificationSession?.stop()
    }

    public func tuneIn(id: String, name: String = "", _ completion: @escaping () -> () = {}) {
        let payload = JSON(
        [
            "playQueueItem": [
                "behaviour": "planned",
                "id": id,
                "station": [
                    "id": id,
                    "image": [
                        [
                            "mediatype": "image/jpg",
                            "size": "medium",
                            "url": ""
                        ]
                    ],
                    "name": name,
                    "tuneIn": [
                        "location": "",
                        "stationId": id
                    ]
                ]
            ]
        ]).rawString()!

        request(method: "DELETE", path: "/BeoZone/Zone/PlayQueue/");
        request(method: "POST", path: "/BeoZone/Zone/PlayQueue/", query: "instantplay", body: payload, completion);
    }

    public func join(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Device/OneWayJoin", completion);
    }

    public func leave(_ completion: @escaping () -> () = {}) {
        request(method: "DELETE", path: "/BeoZone/Zone/ActiveSources/primaryExperience", completion);
    }
}
