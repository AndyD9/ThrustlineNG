import { createFlightStartHandler } from "./handler.ts";

declare const Deno: {
  env: {
    toObject(): Record<string, string>;
  };
  serve(handler: (request: Request) => Promise<Response>): void;
};

Deno.serve(createFlightStartHandler(Deno.env.toObject()));
