import { createFlightCloseHandler } from "./handler.ts";

declare const Deno: {
  env: {
    toObject(): Record<string, string>;
  };
  serve(handler: (request: Request) => Promise<Response>): void;
};

Deno.serve(createFlightCloseHandler(Deno.env.toObject()));
