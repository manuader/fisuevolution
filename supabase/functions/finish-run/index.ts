import { prodDeps } from "../_shared/prod.ts";
import { makeHandlers } from "../_shared/handlers.ts";

const h = makeHandlers(prodDeps());
Deno.serve(h.finishRun);
