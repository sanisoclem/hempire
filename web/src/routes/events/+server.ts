import { register, unregister } from "$lib/server/sse";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = () => {
  let controller: ReadableStreamDefaultController<Uint8Array>;

  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      controller = c;
      register(controller);
    },
    cancel() {
      unregister(controller);
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
};
