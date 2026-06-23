import type { SseEvent } from "$lib/types";

type Controller = ReadableStreamDefaultController<Uint8Array>;

const clients = new Set<Controller>();
const encoder = new TextEncoder();

export function register(controller: Controller): void {
  clients.add(controller);
}

export function unregister(controller: Controller): void {
  clients.delete(controller);
}

export function broadcast(event: SseEvent): void {
  const data = `data: ${JSON.stringify(event)}\n\n`;
  const chunk = encoder.encode(data);
  for (const controller of clients) {
    try {
      controller.enqueue(chunk);
    } catch {
      // client disconnected between the set iteration and enqueue
      clients.delete(controller);
    }
  }
}
