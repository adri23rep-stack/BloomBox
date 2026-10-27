import Foundation
import AudioToolbox

/// Original short navigation cue; system sound playback does not replace a guest audio session.
@MainActor final class LiveBoardNavigationAudio: ObservableObject {
    private var sound: SystemSoundID = 0
    private var lastPlay = Date.distantPast
    func play() {
        guard Date().timeIntervalSince(lastPlay) > 0.07 else { return }
        lastPlay = Date()
        if sound == 0 {
            let rate = 22050, count = 1102
            var pcm = Data()
            for index in 0..<count {
                let t = Double(index) / Double(rate)
                let envelope = sin(Double.pi * Double(index) / Double(count)) * exp(-t * 70)
                var value = Int16(sin(t * 2 * Double.pi * 740) * envelope * 3800).littleEndian
                withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
            }
            var data = Data("RIFF".utf8)
            func u32(_ value: UInt32) { var x = value.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            func u16(_ value: UInt16) { var x = value.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            u32(UInt32(36 + pcm.count)); data.append(Data("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16); data.append(Data("data".utf8)); u32(UInt32(pcm.count)); data.append(pcm)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Strata-Navigation.wav")
            do { try data.write(to: url, options: .atomic) } catch { return }
            guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == kAudioServicesNoError else { sound = 0; return }
        }
        AudioServicesPlaySystemSound(sound)
    }
    func stop() { if sound != 0 { AudioServicesDisposeSystemSoundID(sound); sound = 0 } }
}
