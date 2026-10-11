#if DEBUG
import Darwin
import EconomyKit
import Foundation
import Observation
import QuartzCore

/// Las cuentas de la sonda, sin reloj ni pantalla: una ventana de cuadros y lo que se mide en ella.
struct FrameStats: Equatable, Sendable {
    static let windowSize = 600
    static let slowThreshold: TimeInterval = 0.025

    private var durations: [TimeInterval] = []

    var frameCount: Int { durations.count }
    var slowFrames: Int { durations.filter { $0 > Self.slowThreshold }.count }
    var worstFrameMs: Double { (durations.max() ?? 0) * 1000 }
    var averageFPS: Double {
        let total = durations.reduce(0, +)
        return total > 0 ? Double(durations.count) / total : 0
    }

    mutating func add(frameDuration: TimeInterval) {
        guard frameDuration > 0 else { return }
        durations.append(frameDuration)
        if durations.count > Self.windowSize { durations.removeFirst(durations.count - Self.windowSize) }
    }
}

/// fps, cuadros lentos y memoria de la app, para medir los gates de los videos. Sólo existe en DEBUG.
@MainActor
@Observable
final class FrameRateProbe {
    static let shared = FrameRateProbe()

    private static let refreshEvery = 30
    private static let logEvery: TimeInterval = 10

    private(set) var line = FrameRateProbe.summary(FrameStats(), footprintMB: FrameRateProbe.footprintMB())
    @ObservationIgnored private var stats = FrameStats()
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval = 0
    @ObservationIgnored private var lastLog: CFTimeInterval = 0
    @ObservationIgnored private var framesSinceRefresh = 0

    var isRunning: Bool { link != nil }

    /// Spike T10a: el peor cuadro y los lentos desde la última marca (cambio de piso).
    @ObservationIgnored private(set) var peakMs: Double = 0
    @ObservationIgnored private(set) var peakSlow = 0
    @ObservationIgnored private(set) var peakFrames = 0

    func resetPeak() {
        peakMs = 0
        peakSlow = 0
        peakFrames = 0
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: DisplayLinkTarget(probe: self), selector: #selector(DisplayLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        lastTimestamp = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    fileprivate func tick(timestamp: CFTimeInterval) {
        defer { lastTimestamp = timestamp }
        guard lastTimestamp > 0 else { return }
        let duration = timestamp - lastTimestamp
        stats.add(frameDuration: duration)
        peakMs = max(peakMs, duration * 1000)
        peakFrames += 1
        if duration > FrameStats.slowThreshold { peakSlow += 1 }
        framesSinceRefresh += 1
        if framesSinceRefresh >= Self.refreshEvery {
            framesSinceRefresh = 0
            line = Self.summary(stats, footprintMB: Self.footprintMB())
        }
        if timestamp - lastLog >= Self.logEvery {
            lastLog = timestamp
            Log.lifecycle.info("fps-probe \(self.line, privacy: .public)")
        }
    }

    nonisolated static func summary(_ stats: FrameStats, footprintMB: Double) -> String {
        let fps = Int(stats.averageFPS.rounded())
        let worst = Int(stats.worstFrameMs.rounded())
        return "\(fps) fps · peor \(worst) ms · >25 ms: \(stats.slowFrames) · \(Int(footprintMB.rounded())) MB"
    }

    /// `phys_footprint`: lo que Xcode muestra como memoria de la app.
    nonisolated static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}

/// `CADisplayLink` retiene a su target: este puente evita que retenga a la sonda.
@MainActor
private final class DisplayLinkTarget: NSObject {
    private weak var probe: FrameRateProbe?

    init(probe: FrameRateProbe) {
        self.probe = probe
    }

    @objc func tick(_ link: CADisplayLink) {
        probe?.tick(timestamp: link.timestamp)
    }
}

extension LoopsManifest {
    static let animStressIconID = "stress"

    /// El peor caso de la spec (fondo + popup + ícono) con los videos que ya viajan en el paquete base:
    /// todos los fondos al `.mov` de pantalla completa; el especial y el ícono, al loop con alfa.
    static func animStress(over base: LoopsManifest, content: GameContent) -> LoopsManifest {
        func entry(_ file: String, width: Int, height: Int, alpha: Bool) -> Entry {
            Entry(file: file, width: width, height: height, fps: 24, frames: 121, alpha: alpha, audio: false, odrTag: nil)
        }
        let backdrop = entry("cine_reencarnacion.mov", width: 720, height: 1280, alpha: false)
        let loop = entry("loop_npc_vecina.mov", width: 512, height: 512, alpha: true)
        return LoopsManifest(
            schemaVersion: base.schemaVersion, portraits: base.portraits, objects: base.objects,
            cabin: base.cabin, cinematics: base.cinematics,
            characters: Dictionary(content.specials.specials.map { ($0.id, loop) }, uniquingKeysWith: { first, _ in first }),
            talking: base.talking, visitorActions: base.visitorActions, events: base.events,
            shopIcons: [animStressIconID: loop],
            floors: Dictionary(content.floorTable.floors.map { ($0.background, backdrop) }, uniquingKeysWith: { first, _ in first }))
    }
}
#endif
