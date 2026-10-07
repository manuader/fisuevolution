import simd
import SpriteKit
import UIKit

/// Los efectos de skin por código (PLAN-v2 E6, decisión "Efectos de skin (ORO)").
///
/// Un `SKShader` por efecto, compartido por todos los personajes que lo llevan:
/// SpriteKit dibuja en una sola tanda los sprites con el mismo shader. Lo que
/// varía por personaje va en atributos —`a_phase` (para que no latan
/// sincronizados) y `a_rect` (el rectángulo de la textura en su página de atlas:
/// un efecto que muestrea vecinos no puede leer el sprite de al lado)—, no en
/// uniforms, que valen para todo el shader.
///
/// La velocidad es un uniform (`u_speed`) que Reduce Motion y Bajo consumo bajan
/// a 0: el efecto se ve, quieto.
@MainActor
enum SkinShaders {
    /// Los candidatos del dueño, en su orden. Los que entran a la venta los elige
    /// él en la galería (T2 → T8).
    nonisolated static let ids = ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"]

    private(set) static var speed: Float = 1
    private static var cache: [String: SKShader] = [:]
    private static var observers: [NSObjectProtocol] = []

    static var systemWantsMotion: Bool {
        !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    static func shader(for id: String) -> SKShader? {
        if let cached = cache[id] { return cached }
        guard let body = bodies[id] else { return nil }
        startObservingIfNeeded()
        let shader = SKShader(source: prelude + body, uniforms: [SKUniform(name: "u_speed", float: speed)])
        shader.attributes = [
            SKAttribute(name: "a_phase", type: .float),
            SKAttribute(name: "a_rect", type: .vectorFloat4),
        ]
        cache[id] = shader
        return shader
    }

    /// Pone (o saca, con `nil`) el efecto de un sprite. Se llama cada vez que el
    /// sprite cambia de textura: `a_rect` es el de ESA textura.
    static func apply(_ id: String?, to sprite: SKSpriteNode, phase: Float) {
        guard let id, let shader = shader(for: id) else {
            sprite.shader = nil
            return
        }
        sprite.shader = shader
        let rect = sprite.texture?.textureRect() ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        sprite.setValue(SKAttributeValue(float: phase), forAttribute: "a_phase")
        sprite.setValue(
            SKAttributeValue(vectorFloat4: vector_float4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))),
            forAttribute: "a_rect"
        )
    }

    /// Anima o congela todos los efectos. El uniform se REEMPLAZA (no se escribe
    /// su valor): así no se toca ningún API deprecado de `SKUniform`.
    static func setAnimated(_ animated: Bool) {
        speed = animated ? 1 : 0
        for shader in cache.values {
            shader.removeUniformNamed("u_speed")
            shader.addUniform(SKUniform(name: "u_speed", float: speed))
        }
    }

    private static func startObservingIfNeeded() {
        guard observers.isEmpty else { return }
        speed = systemWantsMotion ? 1 : 0
        let center = NotificationCenter.default
        for name in [UIAccessibility.reduceMotionStatusDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { setAnimated(systemWantsMotion) }
            })
        }
    }

    // MARK: Los programas

    /// Lo que comparten los 8: pasar de la coordenada de la página de atlas a la
    /// del sprite (0…1) y volver, sin salirse del sprite.
    private static let prelude = """
    vec2 skin_local(vec2 uv, vec4 rect) { return (uv - rect.xy) / rect.zw; }
    vec2 skin_atlas(vec2 local, vec4 rect) { return rect.xy + clamp(local, 0.0, 1.0) * rect.zw; }
    float skin_rand(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    vec3 skin_rainbow(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }

    """

    /// Las texturas de SpriteKit vienen premultiplicadas: el color nunca pasa al alfa.
    private static let bodies: [String: String] = [
        "neon": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float d = 0.02;
            float around = texture2D(u_texture, skin_atlas(l + vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l + vec2(0.0, d), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(0.0, d), a_rect)).a;
            float edge = clamp(around * 0.25 - c.a, 0.0, 1.0);
            vec3 glow = vec3(0.25, 1.0, 0.9) * (0.7 + 0.3 * sin(t * 4.0));
            gl_FragColor = vec4(c.rgb + glow * edge, max(c.a, edge));
        }
        """,
        "holograma": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float scan = 0.75 + 0.25 * sin(l.y * 140.0 - t * 6.0);
            float k = 0.8 * (0.85 + 0.15 * sin(t * 23.0));
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            vec3 rgb = min(vec3(0.35, 0.85, 1.0) * luma * 1.4 * scan * k, vec3(c.a * k));
            gl_FragColor = vec4(rgb, c.a * k);
        }
        """,
        "fantasma": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec2 l = skin_local(v_tex_coord, a_rect);
            l.x += sin(l.y * 10.0 + t * 2.0) * 0.015;
            vec4 c = texture2D(u_texture, skin_atlas(l, a_rect));
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            float fade = 0.45 + 0.15 * sin(t * 1.5);
            vec3 ghost = mix(c.rgb, vec3(luma) * vec3(0.85, 0.95, 1.0), 0.7);
            gl_FragColor = vec4(ghost * fade, c.a * fade);
        }
        """,
        "arcoiris": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            vec3 band = skin_rainbow(fract(l.y * 0.8 + t * 0.25));
            gl_FragColor = vec4(mix(c.rgb, band * c.a, 0.45), c.a);
        }
        """,
        "glitch": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec2 l = skin_local(v_tex_coord, a_rect);
            float slice = floor(l.y * 18.0);
            float tick = floor(t * 8.0);
            float jump = step(0.82, skin_rand(vec2(slice, tick))) * (skin_rand(vec2(tick, slice)) - 0.5) * 0.12;
            vec2 g = l + vec2(jump, 0.0);
            vec4 base = texture2D(u_texture, skin_atlas(g, a_rect));
            float r = texture2D(u_texture, skin_atlas(g + vec2(0.012, 0.0), a_rect)).r;
            float b = texture2D(u_texture, skin_atlas(g - vec2(0.012, 0.0), a_rect)).b;
            gl_FragColor = vec4(min(r, base.a), base.g, min(b, base.a), base.a);
        }
        """,
        "pixel": """
        void main() {
            float t = u_time * u_speed + a_phase;
            float cells = 24.0 + 4.0 * sin(t * 0.5);
            vec2 l = skin_local(v_tex_coord, a_rect);
            vec2 p = (floor(l * cells) + 0.5) / cells;
            gl_FragColor = texture2D(u_texture, skin_atlas(p, a_rect));
        }
        """,
        "oro_liquido": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114)) / max(c.a, 0.001);
            vec3 gold = vec3(1.0, 0.78, 0.25) * (0.55 + 0.6 * luma);
            float shine = 1.0 - smoothstep(0.0, 0.08, abs(fract(l.x + l.y * 0.5 - t * 0.35) - 0.5));
            gl_FragColor = vec4(min((gold + vec3(shine)) * c.a, vec3(c.a)), c.a);
        }
        """,
        "sombra": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float d = 0.015;
            float around = texture2D(u_texture, skin_atlas(l + vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l + vec2(0.0, d), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(0.0, d), a_rect)).a;
            float rim = clamp(c.a - around * 0.25, 0.0, 1.0) * 4.0;
            vec3 purple = vec3(0.55, 0.25, 0.85) * (0.7 + 0.3 * sin(t * 2.0));
            gl_FragColor = vec4(min(c.rgb * 0.18 + purple * rim * c.a, vec3(c.a)), c.a);
        }
        """,
    ]
}
