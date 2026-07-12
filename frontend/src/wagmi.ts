import { http, createConfig } from "wagmi";
import { injected } from "wagmi/connectors";
import { hashkey } from "./lib/kembali";

export const config = createConfig({
  chains: [hashkey],
  connectors: [injected()],
  transports: { [hashkey.id]: http("https://mainnet.hsk.xyz") },
});

declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}
