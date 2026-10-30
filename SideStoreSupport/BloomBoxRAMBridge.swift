import Foundation
import UIKit
import Darwin

private let ramRequestKey = "BloomBoxRAMPlusRequest"
private let ramResultKey = "BloomBoxRAMPlusResult"
private func ramDefaults() -> UserDefaults {
    UserDefaults(suiteName: LCSharedUtils.appGroupID()) ?? .standard
}

/// Installed only inside the bundled SideStore process. It observes one narrowly
/// scoped Developer Services response while an explicit, expiring request exists.
/// Passwords, session headers and Apple response bodies never enter preferences/logs.
@objc(BloomBoxRAMProtocol)
final class BloomBoxRAMProtocol: URLProtocol, URLSessionTaskDelegate {
    private var forwardingSession: URLSession?
    private var forwardingTask: URLSessionDataTask?
    private let lifecycleLock = NSLock()
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool {
        guard BloomBoxRAMPortal.isListRequest(request.url), request.httpMethod == "POST",
              URLProtocol.property(forKey: "BloomBoxRAMForwarded", in: request) == nil,
              let plan = ramDefaults().dictionary(forKey: ramRequestKey),
              let expiry = plan["expires"] as? Date, expiry > Date(),
              ramDefaults().bool(forKey: "BloomBoxRAMPlusRequested") else { return false }
        return true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let forwarded = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "BloomBoxRAMForwarded", in: forwarded)
        // Some Foundation transports replace HTTPBody with a stream. Restore it
        // once and forward the exact same bytes, without consuming it twice.
        if forwarded.httpBody == nil, let stream = forwarded.httpBodyStream {
            stream.open(); defer { stream.close() }
            var body = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { client?.urlProtocol(self, didFailWithError: stream.streamError ?? URLError(.cannotDecodeContentData)); return }
                if count == 0 { break }
                body.append(contentsOf: buffer.prefix(count))
                if body.count > 1024 * 1024 { client?.urlProtocol(self, didFailWithError: URLError(.dataLengthExceedsMaximum)); return }
            }
            forwarded.httpBody = body
        }
        let copiedRequest = forwarded as URLRequest
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        forwardingSession = session
        forwardingTask = session.dataTask(with: copiedRequest) { [weak self] data, response, error in
            guard let self else { return }
            self.lifecycleLock.lock(); let stopped = self.stopped; self.lifecycleLock.unlock()
            defer { session.finishTasksAndInvalidate() }
            guard !stopped else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            guard let data, let response else { self.client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
            // Preserve SideStore's original response and timing. RAM+ is a
            // separate task; no signing request or original response is rewritten.
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                BloomBoxRAMJob.receive(request: copiedRequest, data: data)
            }
        }
        forwardingTask?.resume()
    }
    override func stopLoading() {
        lifecycleLock.lock(); stopped = true; lifecycleLock.unlock()
        forwardingTask?.cancel()
        forwardingSession?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // Never forward the session to another destination.
    }
}

private final class BloomBoxRAMJob: NSObject, URLSessionTaskDelegate {
    private static let queue = DispatchQueue(label: "BloomBox.RAMPlus.request")
    private let plan: [String: Any]
    private let headers: [String: String]
    private let response: [String: Any]
    private var lockFD: Int32 = -1
    private var didSubmit = false
    private var approvedBundles: [String] = []
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private var nonce: String { plan["id"] as? String ?? "" }
    private var team: String { plan["team"] as? String ?? "" }

    static func receive(request: URLRequest, data: Data) {
        queue.async {
            let defaults = ramDefaults()
            guard let plan = defaults.dictionary(forKey: ramRequestKey),
                  let id = plan["id"] as? String, !id.isEmpty,
                  let team = plan["team"] as? String,
                  let expiry = plan["expires"] as? Date, expiry > Date(),
                  defaults.bool(forKey: "BloomBoxRAMPlusRequested"),
                  let response = BloomBoxRAMPortal.dictionary(data),
                  let headers = request.allHTTPHeaderFields,
                  request.value(forHTTPHeaderField: "X-Apple-GS-Token")?.isEmpty == false,
                  request.value(forHTTPHeaderField: "X-Apple-I-Identity-Id")?.isEmpty == false else { return }
            if let prior = defaults.dictionary(forKey: ramResultKey), prior["id"] as? String == id,
               let status = prior["status"] as? String, status != "awaitingSession" { return }
            guard BloomBoxRAMPortal.matchesTeam(body: request.httpBody, team: team) else {
                defaults.set(["id": id, "status": "failed", "message": "La cuenta o equipo activo de SideStore no coincide con la firma de BloomBox. Selecciona la cuenta correcta y vuelve a solicitar RAM+.", "date": Date()], forKey: ramResultKey)
                defaults.synchronize()
                return
            }
            let job = BloomBoxRAMJob(plan: plan, headers: headers, response: response)
            guard job.acquireLock() else { return }
            job.save("checking", "Sesión de SideStore detectada. Comprobando los permisos actuales…")
            Task { await job.run() }
        }
    }
    init(plan: [String: Any], headers: [String: String], response: [String: Any]) {
        self.plan = plan
        // Keep only authentication/client headers, in memory, for this operation.
        self.headers = headers.filter { $0.key.lowercased().hasPrefix("x-apple-") || ["x-mme-device-id", "x-mme-client-info", "x-xcode-version", "user-agent", "accept-language"].contains($0.key.lowercased()) }
        self.response = response
    }
    private func acquireLock() -> Bool {
        guard let directory = LCSharedUtils.appGroupPath() else { return false }
        let path = directory.appendingPathComponent("BloomBoxRAMPlus.lock").path
        lockFD = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFD >= 0 else { return false }
        if flock(lockFD, LOCK_EX | LOCK_NB) != 0 { close(lockFD); lockFD = -1; return false }
        return true
    }
    private func current() -> Bool {
        let defaults = ramDefaults()
        return defaults.bool(forKey: "BloomBoxRAMPlusRequested") &&
            defaults.dictionary(forKey: ramRequestKey)?["id"] as? String == nonce &&
            (plan["expires"] as? Date).map { $0 > Date() } == true
    }
    private func requireCurrent() throws {
        guard current() else { throw BloomBoxRAMPortal.fail("Solicitud cancelada o vencida. Si ya se envió a Apple, vuelve a comprobar antes de repetirla.") }
    }
    private func save(_ status: String, _ message: String) {
        let defaults = ramDefaults()
        guard defaults.dictionary(forKey: ramRequestKey)?["id"] as? String == nonce else { return }
        defaults.set(["id": nonce, "status": status, "message": message, "date": Date(), "approvedBundles": approvedBundles], forKey: ramResultKey)
        defaults.synchronize()
    }
    private func run() async {
        defer {
            session.invalidateAndCancel()
            if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
        }
        do {
            try requireCurrent()
            guard let targets = plan["bundles"] as? [String], !targets.isEmpty, targets.count <= 2 else {
                throw BloomBoxRAMPortal.fail("La solicitud no contiene identificadores válidos.")
            }
            var optionalMissing = false
            for (index, bundle) in targets.enumerated() {
                try requireCurrent()
                guard let id = try BloomBoxRAMPortal.appID(in: response, bundle: bundle) else {
                    if index == 0 { throw BloomBoxRAMPortal.fail("BloomBox no aparece en esta cuenta de SideStore. Revisa la cuenta usada para instalarla.") }
                    optionalMissing = true; continue
                }
                let before = try await read(id: id, bundle: bundle)
                if !before.enabled {
                    try requireCurrent()
                    save("requesting", "Solicitando a Apple el permiso para \(bundle)…")
                    didSubmit = true
                    _ = try await send(id: id, method: "PATCH", payload: BloomBoxRAMPortal.payload(before, id: id, bundle: bundle, team: team))
                    try requireCurrent()
                    let after = try await read(id: id, bundle: bundle)
                    guard after.enabled else { throw BloomBoxRAMPortal.fail("Apple respondió, pero no confirmó Increased Memory Limit. No se marcará como activado.") }
                }
                approvedBundles.append(bundle)
            }
            let note = optionalMissing ? " LiveProcess no tiene un App ID separado en esta cuenta; se verificará su firma tras reinstalar." : ""
            let message = "Apple confirmó el permiso. Ahora reinstala BloomBox desde SideStore conservando sus extensiones y sin borrar la app. Después vuelve a RAM+ para comprobar la instalación." + note
            save("approved", message)
            await showResult(message)
        } catch {
            let partial = approvedBundles.isEmpty ? "" : " El permiso ya fue confirmado para: \(approvedBundles.joined(separator: ", "))."
            let message = error.localizedDescription + partial
            save(didSubmit ? "uncertain" : "failed", message)
            await showResult(message)
        }
    }
    private func read(id: String, bundle: String) async throws -> BloomBoxRAMPortal.Snapshot {
        let response = try await send(id: id, method: "GET", payload: nil)
        return try BloomBoxRAMPortal.snapshot(response, id: id, bundle: bundle, team: team)
    }
    private func send(id: String, method: String, payload: [String: Any]?) async throws -> [String: Any] {
        try requireCurrent()
        guard BloomBoxRAMPortal.validID(id), let url = URL(string: "https://\(BloomBoxRAMPortal.host)/services/v1/bundleIds/\(id)") else {
            throw BloomBoxRAMPortal.fail("El App ID no es válido.")
        }
        var request = URLRequest(url: url)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let payload {
            request.httpMethod = method
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } else {
            var query = URLComponents()
            query.queryItems = [URLQueryItem(name: "teamId", value: team),
                               URLQueryItem(name: "include", value: "bundleIdCapabilities,bundleIdCapabilities.capability"),
                               URLQueryItem(name: "fields[bundleIds]", value: "identifier,name,seedId,bundleType,hasExclusiveManagedCapabilities,bundleIdCapabilities"),
                               URLQueryItem(name: "limit[bundleIdCapabilities]", value: "50")]
            request.httpMethod = "POST"
            request.setValue("GET", forHTTPHeaderField: "X-HTTP-Method-Override")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["urlEncodedQueryParams": query.percentEncodedQuery ?? "", "teamId": team])
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BloomBoxRAMPortal.fail("Apple no devolvió una respuesta válida.") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 { throw BloomBoxRAMPortal.fail("Apple rechazó la sesión o el permiso (\(http.statusCode)). Revisa el inicio de sesión de SideStore.") }
            throw BloomBoxRAMPortal.fail("Apple rechazó la solicitud (HTTP \(http.statusCode)). La activación no está confirmada.")
        }
        // Apple/SideSign may return an empty success body to PATCH. We never
        // treat it as a grant: run() must perform a fresh GET and confirm RAM+.
        return try BloomBoxRAMPortal.validatedResponse(data, statusCode: http.statusCode, method: method)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    @MainActor private func showResult(_ message: String) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        guard !(top is UIAlertController) else { return }
        let alert = UIAlertController(title: "RAM+ · BloomBox", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Entendido", style: .default))
        top.present(alert, animated: true)
    }
}
