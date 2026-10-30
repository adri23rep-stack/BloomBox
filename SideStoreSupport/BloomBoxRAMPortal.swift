import Foundation

/// Pure request validation/planning. No Apple credentials are persisted here.
enum BloomBoxRAMPortal {
    static let capability = "INCREASED_MEMORY_LIMIT"
    static let host = "developerservices2.apple.com"
    static let listPath = "/services/QH65B2/ios/listAppIds.action"
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func fail(_ message: String) -> Failure { Failure(message: message) }
    static func isListRequest(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && url.host == host && url.port == nil && url.user == nil && url.password == nil && url.path == listPath
    }
    static func dictionary(_ data: Data) -> [String: Any]? {
        guard data.count <= 4 * 1024 * 1024 else { return nil }
        return ((try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any])
            ?? ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
    }
    /// Developer Services can acknowledge a PATCH with no JSON body. A successful
    /// HTTP response alone is never proof of activation: callers must read back
    /// the capability before reporting Apple approval.
    static func validatedResponse(_ data: Data, statusCode: Int, method: String) throws -> [String: Any] {
        guard (200..<300).contains(statusCode) else {
            throw fail("Apple rechazó la solicitud (HTTP \(statusCode)). RAM+ no está confirmada.")
        }
        if data.isEmpty && method == "PATCH" { return [:] }
        guard let response = dictionary(data), response["errors"] == nil else {
            throw fail("Apple devolvió datos incompletos o con errores. RAM+ no está confirmada.")
        }
        return response
    }
    static func matchesTeam(body: Data?, team: String) -> Bool {
        guard !team.isEmpty, let body else { return false }
        return dictionary(body)?["teamId"] as? String == team
    }
    static func appID(in response: [String: Any], bundle: String) throws -> String? {
        guard let code = response["resultCode"] as? NSNumber, code.intValue == 0,
              let apps = response["appIds"] as? [[String: Any]] else {
            throw fail("SideStore no pudo consultar los App IDs. Revisa su sesión e inténtalo otra vez.")
        }
        let matches = apps.filter { $0["identifier"] as? String == bundle }
        guard matches.count <= 1 else { throw fail("Apple devolvió identificadores duplicados; no se modificó nada.") }
        guard let match = matches.first else { return nil }
        guard let id = match["appIdId"] as? String, validID(id) else { throw fail("El App ID recibido no es válido.") }
        return id
    }
    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 128 && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) && $0.isASCII }
    }
    struct Snapshot {
        let resource: [String: Any]
        let capabilities: [[String: Any]]
        var enabled: Bool {
            capabilities.contains { item in
                let relations = item["relationships"] as? [String: Any]
                let cap = relations?["capability"] as? [String: Any]
                let data = cap?["data"] as? [String: Any]
                let attrs = item["attributes"] as? [String: Any]
                return data?["id"] as? String == capability && strictBool(attrs?["enabled"]) == true
            }
        }
    }
    static func strictBool(_ value: Any?) -> Bool? {
        guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
        return n.boolValue
    }
    static func snapshot(_ response: [String: Any], id: String, bundle: String, team: String) throws -> Snapshot {
        guard response["errors"] == nil,
              let resource = response["data"] as? [String: Any],
              resource["type"] as? String == "bundleIds", resource["id"] as? String == id,
              let attrs = resource["attributes"] as? [String: Any],
              attrs["identifier"] as? String == bundle,
              // The selected team is also sent in every read and write. If Apple
              // supplies a team ID, never accept a mismatch.
              (attrs["teamId"] == nil || attrs["teamId"] as? String == team),
              let relations = resource["relationships"] as? [String: Any],
              let caps = relations["bundleIdCapabilities"] as? [String: Any],
              let refs = caps["data"] as? [[String: Any]] else {
            throw fail("No se pudo verificar el App ID y sus permisos actuales. No se modificó nada.")
        }
        let links = caps["links"] as? [String: Any]
        if let next = links?["next"], !(next is NSNull) { throw fail("La lista de permisos está incompleta; no se modificó nada.") }
        if let total = (caps["meta"] as? [String: Any])?["paging"] as? [String: Any],
           let count = total["total"] as? Int, count != refs.count { throw fail("La lista de permisos está incompleta.") }
        let included = response["included"] as? [[String: Any]] ?? []
        var resolved: [[String: Any]] = []
        var seen = Set<String>()
        for ref in refs {
            guard ref["type"] as? String == "bundleIdCapabilities", let capID = ref["id"] as? String,
                  seen.insert(capID).inserted else { throw fail("La lista de permisos no es válida.") }
            let items = included.filter { $0["type"] as? String == "bundleIdCapabilities" && $0["id"] as? String == capID }
            let item = ref["attributes"] != nil ? ref : (items.count == 1 ? items[0] : [:])
            guard let values = item["attributes"] as? [String: Any], strictBool(values["enabled"]) != nil,
                  let relationships = item["relationships"] as? [String: Any],
                  let capabilityRelation = relationships["capability"] as? [String: Any],
                  let capabilityData = capabilityRelation["data"] as? [String: Any],
                  capabilityData["id"] is String else { throw fail("Faltan detalles de los permisos actuales; no se modificó nada.") }
            resolved.append(item)
        }
        return Snapshot(resource: resource, capabilities: resolved)
    }
    static func payload(_ snapshot: Snapshot, id: String, bundle: String, team: String) -> [String: Any] {
        var caps = snapshot.capabilities.map { item -> [String: Any] in
            var copy = item
            copy.removeValue(forKey: "links")
            copy.removeValue(forKey: "meta")
            return copy
        }
        let index = caps.firstIndex { item in
            let r = item["relationships"] as? [String: Any]
            return ((r?["capability"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == capability
        }
        if let index {
            var attrs = caps[index]["attributes"] as? [String: Any] ?? [:]
            attrs["enabled"] = true
            caps[index]["attributes"] = attrs
        } else {
            caps.append(["type": "bundleIdCapabilities", "attributes": ["enabled": true, "settings": []],
                         "relationships": ["capability": ["data": ["type": "capabilities", "id": capability]]]])
        }
        let previous = snapshot.resource["attributes"] as? [String: Any] ?? [:]
        let attrs: [String: Any] = ["identifier": bundle, "teamId": team, "seedId": previous["seedId"] ?? team,
                                   "bundleType": previous["bundleType"] ?? "bundle", "name": previous["name"] ?? "BloomBox",
                                   "hasExclusiveManagedCapabilities": previous["hasExclusiveManagedCapabilities"] ?? false]
        return ["data": ["type": "bundleIds", "id": id, "attributes": attrs,
                          "relationships": ["bundleIdCapabilities": ["data": caps]]]]
    }
}
import CoreFoundation
