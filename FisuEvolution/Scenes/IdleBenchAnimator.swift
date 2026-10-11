import CoreGraphics
import Foundation
import ImageIO
import os
import SpriteKit
import UIKit

/// Spike E8e T10a (rama desechable): los cuadros del clip base en los personajes sin pinta del piso
/// visible, con la variante que pida el banco. No se integra: T10c lo reescribe con tests.
struct IdleBenchConfig: Sendable {
    enum Format: String, Sendable { case png8 = "A", astc = "C" }

    let enabled: Bool
    let format: Format
    let frames: Int
    let side: Int
    let loopSeconds: Double
    let fps: Double?
    let maxAnimated: Int?

    static let current = IdleBenchConfig(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        enabled = arguments.contains("--uitest-idle-bench")
        func value(_ prefix: String) -> String? {
            arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        let variant = value("--idle-variant=") ?? "A16x256"
        format = Format(rawValue: String(variant.prefix(1))) ?? .png8
        let numbers = variant.dropFirst().split(separator: "x").compactMap { Int($0) }
        frames = numbers.first ?? 16
        side = numbers.count > 1 ? numbers[1] : 256
        loopSeconds = 120.0 / 24.0
        fps = value("--idle-fps=").flatMap(Double.init)
        maxAnimated = value("--idle-max=").flatMap(Int.init)
    }

    var timePerFrame: TimeInterval { fps.map { 1 / $0 } ?? loopSeconds / Double(frames) }
    var label: String { "\(format.rawValue)\(frames)x\(side)" }

    func sheetName(for type: String) -> String {
        frames == 16 && side == 256 ? "idle_\(type)" : "idle_\(type)_n\(frames)_l\(side)"
    }
}

@MainActor
final class IdleBenchAnimator {
    private enum Entry {
        case waiting(generation: Int, tag: String, token: UUID)
        case decoding(generation: Int, tag: String)
        case uploading(generation: Int, tag: String, frames: [SKTexture], decode: Duration, start: ContinuousClock.Instant)
        case ready(tag: String, frames: [SKTexture])
    }

    private static let signposter = OSSignposter(subsystem: "com.manuader.fisuevolution", category: "idle")
    private let config = IdleBenchConfig.current
    private let packs: ArtPacks
    private let pool: VideoPlayerPool
    private let loops: LoopsManifest
    private var entries: [String: Entry] = [:]
    private var nodes: [Int: CharacterNode] = [:]
    private var animatable: Set<Int> = []
    private var generation = 0
    private var memoryLocked = false
    private var memoryObserver: NSObjectProtocol?
    private var unskinned: Set<Int> = []
    private var lastAllowsLoops: Bool?

    init(packs: ArtPacks, pool: VideoPlayerPool, loops: LoopsManifest) {
        self.packs = packs
        self.pool = pool
        self.loops = loops
        guard config.enabled else { return }
        let xctest = NSClassFromString("XCTestCase") != nil
        Log.board.info("idle-bench config \(self.config.label, privacy: .public) tpf \(self.config.timePerFrame, privacy: .public) xctestLoaded \(xctest)")
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.memoryWarning() }
        }
    }

    /// Sin observador de la política en el spike: la escena la mira cada cuadro (un `Bool`).
    func pollPolicy() {
        guard config.enabled, lastAllowsLoops != pool.policy.allowsLoops else { return }
        sync(nodes: nodes, unskinned: unskinned)
    }

    func sync(nodes: [Int: CharacterNode], unskinned: Set<Int>) {
        guard config.enabled else { return }
        self.nodes = nodes
        self.unskinned = unskinned
        lastAllowsLoops = pool.policy.allowsLoops
        let realArt = nodes.values.filter(\.showsRealArt).count
        let allows = pool.policy.allowsLoops
        let reasons = String(describing: pool.policy.reasons)
        Log.board.info("idle-bench policy \(reasons, privacy: .public) thermal \(ProcessInfo.processInfo.thermalState.rawValue) lowPower \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        Log.board.info("idle-bench sync nodes \(nodes.count) unskinned \(unskinned.count) realArt \(realArt) allowsLoops \(allows) locked \(self.memoryLocked)")
        guard !memoryLocked, allows else {
            animatable = []
            entries.keys.forEach(unload)
            return
        }
        var slots = unskinned.filter { nodes[$0]?.showsRealArt == true }
        if let limit = config.maxAnimated, slots.count > limit {
            let points = slots.compactMap { nodes[$0]?.position }
            let center = CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                                 y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
            func distance(_ slot: Int) -> CGFloat {
                guard let p = nodes[slot]?.position else { return .greatestFiniteMagnitude }
                return hypot(p.x - center.x, p.y - center.y)
            }
            slots = Set(slots.sorted { distance($0) < distance($1) }.prefix(limit))
        }
        animatable = slots
        let wanted = Set(slots.compactMap { nodes[$0]?.typeId })
        for type in entries.keys where !wanted.contains(type) { unload(type) }
        for type in wanted where entries[type] == nil { load(type) }
        for (slot, node) in nodes where !slots.contains(slot) && node.isIdleAnimating { node.stopIdleFrames() }
        for type in wanted { apply(type) }
    }

    private func load(_ type: String) {
        guard let tag = loops.characters[type]?.odrTag else { return }
        generation += 1
        let current = generation
        packs.request(tag)
        entries[type] = .waiting(generation: current, tag: tag, token: UUID())
        let token = packs.whenAvailable(tag) { [weak self] in self?.packArrived(type, generation: current) }
        if case .waiting(current, _, _)? = entries[type] {
            entries[type] = .waiting(generation: current, tag: tag, token: token)
        }
    }

    private func packArrived(_ type: String, generation current: Int) {
        guard case let .waiting(generation, tag, _)? = entries[type], generation == current else { return }
        entries[type] = .decoding(generation: current, tag: tag)
        switch config.format {
        case .png8: decodeSheet(type, tag: tag, generation: current)
        case .astc: preloadAtlas(type, tag: tag, generation: current)
        }
    }

    private func decodeSheet(_ type: String, tag: String, generation current: Int) {
        guard let url = Bundle.main.url(forResource: config.sheetName(for: type), withExtension: "png") else {
            Log.board.error("idle-bench sin hoja \(self.config.sheetName(for: type), privacy: .public)")
            return
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let start = ContinuousClock.now
            let image = Self.decodeRGBA(url)
            let elapsed = start.duration(to: .now)
            await self?.sheetDecoded(type, generation: current, image: image.map(SendableImage.init), elapsed: elapsed)
        }
    }

    private func sheetDecoded(_ type: String, generation current: Int, image: SendableImage?, elapsed: Duration) {
        guard case let .decoding(generation, tag)? = entries[type], generation == current, let image else { return }
        let mainStart = ContinuousClock.now
        let sheet = SKTexture(cgImage: image.image)
        let columns = Int(Double(config.frames).squareRoot().rounded(.up))
        let rows = (config.frames + columns - 1) / columns
        let frames = (0..<config.frames).map { index in
            let column = index % columns, row = index / columns
            return SKTexture(rect: CGRect(x: CGFloat(column) / CGFloat(columns),
                                          y: 1 - CGFloat(row + 1) / CGFloat(rows),
                                          width: 1 / CGFloat(columns), height: 1 / CGFloat(rows)), in: sheet)
        }
        entries[type] = .uploading(generation: current, tag: tag, frames: frames, decode: elapsed, start: .now)
        SKTexture.preload([sheet]) { [weak self] in
            Task { @MainActor in self?.preloaded(type, generation: current) }
        }
        Log.board.info("idle-bench main-textures \(type, privacy: .public) \(Self.ms(mainStart.duration(to: .now)), privacy: .public) ms")
    }

    private func preloadAtlas(_ type: String, tag: String, generation current: Int) {
        let mainStart = ContinuousClock.now
        let atlas = SKTextureAtlas(named: "idle_\(type)")
        let frames = (0..<config.frames).map { atlas.textureNamed(String(format: "idle_%@_%02d", type, $0)) }
        entries[type] = .uploading(generation: current, tag: tag, frames: frames, decode: .zero, start: .now)
        SKTexture.preload(frames) { [weak self] in
            Task { @MainActor in self?.preloaded(type, generation: current) }
        }
        Log.board.info("idle-bench main-textures \(type, privacy: .public) \(Self.ms(mainStart.duration(to: .now)), privacy: .public) ms")
    }

    private func preloaded(_ type: String, generation current: Int) {
        guard case let .uploading(generation, tag, frames, decode, start)? = entries[type], generation == current
        else { return }
        let upload = start.duration(to: .now)
        entries[type] = .ready(tag: tag, frames: frames)
        Log.board.info("idle-bench ready \(type, privacy: .public) decode \(Self.ms(decode), privacy: .public) ms upload \(Self.ms(upload), privacy: .public) ms")
        apply(type)
    }

    private func apply(_ type: String) {
        guard case let .ready(_, frames)? = entries[type] else { return }
        let state = Self.signposter.beginInterval("apply")
        let start = ContinuousClock.now
        var count = 0
        for slot in animatable {
            guard let node = nodes[slot], node.typeId == type, !node.isIdleAnimating, node.parent != nil else { continue }
            node.runIdleFrames(frames, timePerFrame: config.timePerFrame, phase: slot &* 5)
            count += 1
        }
        Self.signposter.endInterval("apply", state)
        if count > 0 {
            Log.board.info("idle-bench apply \(type, privacy: .public) nodes \(count) main \(Self.ms(start.duration(to: .now)), privacy: .public) ms")
        }
    }

    private func unload(_ type: String) {
        guard let entry = entries.removeValue(forKey: type) else { return }
        for node in nodes.values where node.typeId == type && node.isIdleAnimating { node.stopIdleFrames() }
        switch entry {
        case let .waiting(_, tag, token):
            packs.cancelWait(tag, token: token)
            packs.release(tag)
        case let .decoding(_, tag), let .ready(tag, _), let .uploading(_, tag, _, _, _):
            packs.release(tag)
        }
    }

    private func memoryWarning() {
        memoryLocked = true
        var stopped = 0
        var restored = 0
        for node in nodes.values where node.isIdleAnimating {
            stopped += 1
            if node.stopIdleFrames() { restored += 1 }
        }
        entries.keys.forEach(unload)
        let stillAnimating = nodes.values.filter(\.isIdleAnimating).count
        Log.board.info("idle-bench memwarn stopped \(stopped) restoredByAction \(restored) animating-now \(stillAnimating)")
    }

    private nonisolated static func decodeRGBA(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private nonisolated static func ms(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        return String(format: "%.1f", Double(seconds) * 1000 + Double(attoseconds) / 1e15)
    }
}

private struct SendableImage: @unchecked Sendable {
    let image: CGImage
}
