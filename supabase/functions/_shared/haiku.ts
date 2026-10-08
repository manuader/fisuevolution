import Anthropic from "@anthropic-ai/sdk";

export type Classifier = (
  name: string,
  signal: AbortSignal,
) => Promise<"ok" | "reject" | "unavailable">;

export const MODEL = "claude-haiku-5-5";

const SYSTEM =
  `Moderás nombres de jugadores para un ranking público de un juego móvil argentino.
Respondé sólo con el JSON pedido. ok=false si el nombre, en español rioplatense o en inglés, es
ofensivo, discriminatorio, sexual, violento, o se hace pasar por el juego, sus creadores o el
equipo de soporte ("Fisu Oficial", "Admin", "Soporte"). Cualquier otro nombre, aunque sea raro o
gracioso, es ok=true.`;

/** Un fallo, un rechazo del modelo o un timeout son "unavailable": queda pendiente y reintenta el cron. */
export function haikuClassifier(apiKey: string): Classifier {
  const client = new Anthropic({ apiKey, timeout: 5_000, maxRetries: 0 });
  return async (name, signal) => {
    try {
      const message = await client.messages.create({
        model: MODEL,
        max_tokens: 256,
        thinking: { type: "disabled" },
        system: SYSTEM,
        output_config: {
          effort: "low",
          format: {
            type: "json_schema",
            schema: {
              type: "object",
              properties: { ok: { type: "boolean" } },
              required: ["ok"],
              additionalProperties: false,
            },
          },
        },
        messages: [{ role: "user", content: `Nombre: ${JSON.stringify(name)}` }],
      }, { signal });
      if (message.stop_reason === "refusal") return "unavailable";
      const block = message.content.find((b) => b.type === "text");
      const text = block && block.type === "text" ? block.text : "";
      return JSON.parse(text).ok === true ? "ok" : "reject";
    } catch {
      return "unavailable";
    }
  };
}
