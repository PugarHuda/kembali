import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useAccount, useChainId, useConnect, useSwitchChain, usePublicClient, useWalletClient, useDisconnect } from "wagmi";
import { hashTypedData } from "viem";
import { ADDR, kembaliAbi, erc20Abi, nftAbi, hashkey, STATUS, statusColor, fmtUsdc, short, explorerAddr } from "../lib/kembali";
import { buildMandate, MANDATE_TYPES } from "../lib/mandate";
import { useStore } from "../store";

type View = "overview" | "open" | "settle" | "agent" | "faucet" | "contract";
const NAV: [View, string][] = [
  ["overview", "Overview"], ["open", "Open Escrow"], ["settle", "Settle"],
  ["agent", "Agent"], ["faucet", "Faucet"], ["contract", "Contract"],
];

interface Esc { status: string; deadline: number; amount: bigint }

export default function DApp() {
  const [view, setView] = useState<View>("overview");
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { connectAsync, connectors } = useConnect();
  const { switchChainAsync } = useSwitchChain();
  const pc = usePublicClient();
  const { data: wallet, refetch: refetchWallet } = useWalletClient();
  const { disconnect, disconnectAsync } = useDisconnect();
  const { paymentId, setPaymentId, deliverableApproved, setDeliverableApproved, flash } = useStore();

  const [form, setForm] = useState({
    merchant: ADDR.merchant, payToken: ADDR.demoUsdc, amount: "100000000",
    window: "86400", asset: ADDR.demoNft, item: "1", kind: "0",
  });
  const [kusd, setKusd] = useState<bigint>(0n);
  const [esc, setEsc] = useState<Esc | null>(null);
  const [tick, setTick] = useState(Date.now());
  useEffect(() => { const t = setInterval(() => setTick(Date.now()), 1000); return () => clearInterval(t); }, []);

  const set = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }));
  const wrongNet = isConnected && chainId !== hashkey.id;

  async function ensureChain() {
    if (chainId !== hashkey.id) await switchChainAsync({ chainId: hashkey.id });
  }
  async function connect() {
    const c = connectors[0];
    if (!c) return flash("No wallet found — install MetaMask");
    try {
      await connectAsync({ connector: c });
      await ensureChain().catch(() => {});
    } catch (e: any) {
      flash(e?.name === "UserRejectedRequestError" ? "Connection cancelled" : "Connect failed");
    }
  }
  async function reconnect() {
    await disconnectAsync().catch(() => {}); // drop the stale session, then re-request accounts
    await connect();
  }

  type Wallet = NonNullable<typeof wallet>;
  async function run(label: string, fn: (w: Wallet) => Promise<`0x${string}` | undefined>) {
    if (!isConnected) return flash("Connect a wallet first");
    // useWalletClient's data lags a tick behind isConnected right after connect — refetch instead of failing.
    let w = wallet;
    if (!w) w = (await refetchWallet()).data ?? undefined;
    if (!w) return flash("Wallet not ready — reconnect");
    try {
      await ensureChain();
      flash(label + "…");
      const hash = await fn(w);
      if (hash && pc) await pc.waitForTransactionReceipt({ hash });
      flash(label + " ✓");
      refreshBalance();
      readStatus(useStore.getState().paymentId); // read AFTER the receipt — fixed 400/600ms timeouts raced the 2s block and showed stale status
    } catch (e: any) {
      flash("Error: " + (e?.shortMessage || e?.message || "failed").slice(0, 90));
    }
  }

  async function refreshBalance() {
    if (!pc || !address) return;
    try { setKusd((await pc.readContract({ address: form.payToken as `0x${string}`, abi: erc20Abi, functionName: "balanceOf", args: [address] })) as bigint); } catch {}
  }
  useEffect(() => { refreshBalance(); }, [address, form.payToken]);

  async function readStatus(id = paymentId) {
    if (!pc || !id) return;
    const p: any = await pc.readContract({ address: ADDR.kembali, abi: kembaliAbi, functionName: "payments", args: [id as `0x${string}`] });
    setEsc({ status: STATUS[Number(p[8])], deadline: Number(p[7]) * 1000, amount: p[3] as bigint });
  }
  useEffect(() => { if (paymentId) readStatus(); /* eslint-disable-next-line */ }, [paymentId]);

  // ---- actions ----
  const mintKusd = () => run("Minted 1000 kUSD", async (w) =>
    w.writeContract({ address: form.payToken as `0x${string}`, abi: erc20Abi, functionName: "mint", args: [address!, 1_000_000000n] }));
  const mintNft = () => run("Minted demo NFT", async (w) =>
    w.writeContract({ address: form.asset as `0x${string}`, abi: nftAbi, functionName: "mint", args: [address!] }));
  const approve = () => run("Approved pay token", async (w) =>
    w.writeContract({ address: form.payToken as `0x${string}`, abi: erc20Abi, functionName: "approve", args: [ADDR.kembali, BigInt(form.amount)] }));

  async function doOpen(w: Wallet) {
    await ensureChain();
    const now = (await pc!.getBlock({ blockTag: "latest" })).timestamp;
    const { domain, message } = buildMandate({
      signer: address!, kembali: ADDR.kembali, token: form.payToken as `0x${string}`,
      amount: BigInt(form.amount), merchant: form.merchant as `0x${string}`, asset: form.asset as `0x${string}`,
      item: BigInt(form.item), kind: Number(form.kind), window: BigInt(form.window), now,
    });
    const signature = await w.signTypedData({ account: address!, domain, types: MANDATE_TYPES, primaryType: "Mandate", message });
    const id = hashTypedData({ domain, types: MANDATE_TYPES, primaryType: "Mandate", message });
    const hash = await w.writeContract({
      address: ADDR.kembali, abi: kembaliAbi, functionName: "open",
      args: [message as any, signature, form.merchant as `0x${string}`, form.asset as `0x${string}`, BigInt(form.item), Number(form.kind), BigInt(form.window)],
    });
    setPaymentId(id); setDeliverableApproved(false);
    return { hash, id };
  }
  const open = () => run("Escrow opened", async (w) => {
    const { hash } = await doOpen(w);
    setTimeout(() => setView("settle"), 400); // status is refreshed by run() after the receipt
    return hash;
  });

  const approveDeliverable = () => run("Deliverable approved", async (w) => {
    const h = Number(form.kind) === 0
      ? await w.writeContract({ address: form.asset as `0x${string}`, abi: nftAbi, functionName: "setApprovalForAll", args: [ADDR.kembali, true] })
      : await w.writeContract({ address: form.asset as `0x${string}`, abi: erc20Abi, functionName: "approve", args: [ADDR.kembali, BigInt(form.item)] });
    setDeliverableApproved(true);
    return h;
  });
  const fulfill = () => run("Delivered — merchant credited", async (w) => w.writeContract({ address: ADDR.kembali, abi: kembaliAbi, functionName: "fulfill", args: [paymentId as `0x${string}`] }));
  const refund = () => run("Refund credited to payer", async (w) => w.writeContract({ address: ADDR.kembali, abi: kembaliAbi, functionName: "refund", args: [paymentId as `0x${string}`] }));
  const cancel = () => run("Cancelled — payer credited", async (w) => w.writeContract({ address: ADDR.kembali, abi: kembaliAbi, functionName: "cancel", args: [paymentId as `0x${string}`] }));
  const withdraw = () => run("Withdrawn", async (w) => w.writeContract({ address: ADDR.kembali, abi: kembaliAbi, functionName: "withdraw", args: [form.payToken as `0x${string}`] }));

  const agentBuy = () => run("🤖 Agent bought — recourse guaranteed", async (w) => {
    // Wait for each tx receipt before the next — fixed sleeps race the 2s block time and open() reverts on TRANSFER_FROM_FAIL.
    const h1 = await w.writeContract({ address: form.payToken as `0x${string}`, abi: erc20Abi, functionName: "mint", args: [address!, BigInt(form.amount)] });
    await pc!.waitForTransactionReceipt({ hash: h1 });
    const h2 = await w.writeContract({ address: form.payToken as `0x${string}`, abi: erc20Abi, functionName: "approve", args: [ADDR.kembali, BigInt(form.amount)] });
    await pc!.waitForTransactionReceipt({ hash: h2 });
    const { hash } = await doOpen(w);
    setTimeout(() => setView("settle"), 400); // status refreshed by run() after the receipt
    return hash;
  });

  // ---- derived ----
  const windowLeft = useMemo(() => {
    if (!esc || esc.status !== "HELD") return "—";
    const s = Math.max(0, Math.floor((esc.deadline - tick) / 1000));
    if (s === 0) return "refund open";
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60;
    return h > 0 ? `${h}h ${m}m` : `${m}m ${ss}s`;
  }, [esc, tick]);
  const status = esc?.status || "NONE";
  const viewTitle = NAV.find((n) => n[0] === view)![1];

  return (
    <div className="app">
      <aside className="side">
        <div className="side-top"><div className="wordmark" style={{ fontSize: 20 }}>Kembali <span className="label">App</span></div></div>
        <div className="wallet-block">
          <div className="label" style={{ marginBottom: 6 }}>HashKey · 177</div>
          {isConnected ? (
            <div>
              <div className="mono" style={{ fontSize: 12, color: "var(--ink)", marginBottom: 6 }}>{short(address, 4)}{wrongNet && <span style={{ color: "var(--accent)" }}> · wrong net</span>}</div>
              <div style={{ display: "flex", gap: 6 }}>
                <button className="btn ghost" style={{ flex: 1, justifyContent: "center", padding: "3px 8px", fontSize: 11 }} onClick={reconnect}>Reconnect</button>
                <button className="btn ghost" style={{ flex: 1, justifyContent: "center", padding: "3px 8px", fontSize: 11 }} onClick={() => disconnect()}>Disconnect</button>
              </div>
            </div>
          ) : (
            <button className="btn accent" style={{ width: "100%", justifyContent: "center" }} onClick={connect}>Connect Wallet</button>
          )}
        </div>
        <nav className="nav">
          {NAV.map(([v, l]) => (
            <button key={v} className={view === v ? "on" : ""} onClick={() => setView(v)}>{l}</button>
          ))}
        </nav>
        <Link to="/" className="side-foot">← Back to site</Link>
      </aside>

      <main className="main">
        <div className="main-head">
          <h1>{viewTitle}</h1>
          <span className="statuspill"><span className="dot" style={{ background: statusColor[status] }} />{status === "NONE" ? "Idle" : status}</span>
        </div>

        {view === "overview" && (
          <div className="view">
            <div className="tiles">
              <div className="tile"><div className="tl">Wallet Balance</div><div className="tv">{fmtUsdc(kusd)}</div><div className="ts">kUSD</div></div>
              <div className="tile"><div className="tl">Active Escrow</div><div className="tv">{esc ? fmtUsdc(esc.amount) : "—"}</div><div className="ts">{status === "NONE" ? "no escrow" : status}</div></div>
              <div className="tile"><div className="tl">Window Left</div><div className="tv" style={{ fontSize: 26 }}>{windowLeft}</div><div className="ts">until refund opens</div></div>
            </div>
            <div className="panel">
              <div className="eyebrow">01 / Start</div>
              <h2 style={{ marginTop: ".5rem" }}>Reversible escrow, in three moves.</h2>
              <p className="sub">Fund a payment held against an on-chain deliverable. The merchant delivers to get paid — or, past the window, the money returns to you. No arbiter.</p>
              <div className="btnrow">
                <button className="btn accent" onClick={() => setView("open")}>Open an Escrow →</button>
                <button className="btn outline" onClick={() => setView("settle")}>Settle →</button>
                <button className="btn ghost" onClick={() => setView("agent")}>🤖 Agent Buy</button>
              </div>
            </div>
          </div>
        )}

        {view === "open" && (
          <div className="view">
            <div className="panel">
              <div className="field"><label>Merchant · seeded, owns demo NFT #1</label><input value={form.merchant} onChange={(e) => set("merchant", e.target.value)} /></div>
              <div className="grid2">
                <div className="field"><label>Pay token · DemoUSDC (6 dec)</label><input value={form.payToken} onChange={(e) => set("payToken", e.target.value)} /></div>
                <div className="field"><label>Amount · 6 dec</label><input value={form.amount} onChange={(e) => set("amount", e.target.value)} /><div className="hint">= {fmtUsdc(BigInt(form.amount || "0"))} USDC</div></div>
              </div>
              <div className="grid2">
                <div className="field"><label>Window · sec</label><input value={form.window} onChange={(e) => set("window", e.target.value)} /><div className="hint">refund opens after this · use <b onClick={() => set("window", "120")} style={{ cursor: "pointer", color: "var(--accent)" }}>120</b> to demo reversal fast</div></div>
                <div className="field"><label>Item · id / amount</label><input value={form.item} onChange={(e) => set("item", e.target.value)} /></div>
              </div>
              <div className="field"><label>Deliverable asset · DemoNFT</label><input value={form.asset} onChange={(e) => set("asset", e.target.value)} /></div>
              <div className="field"><label>Kind</label><div className="seg">
                <button className={form.kind === "0" ? "on" : ""} onClick={() => set("kind", "0")}>NFT · 0</button>
                <button className={form.kind === "1" ? "on" : ""} onClick={() => set("kind", "1")}>ERC20 · 1</button>
              </div></div>
              <div className="btnrow">
                <button className="btn outline" onClick={approve}>1 · Approve</button>
                <button className="btn accent" onClick={open}>2 · Open Escrow</button>
              </div>
              <p className="hint" style={{ marginTop: "1rem" }}>Signs an EIP-712 mandate; the digest becomes the escrow id (paymentId), viewable under Contract.</p>
            </div>
          </div>
        )}

        {view === "settle" && (
          <div className="view">
            <div className="statusline">
              <span className="dot" style={{ background: statusColor[status] }} />
              <b>{status}</b>
              <span style={{ color: "var(--muted)" }}>{paymentId ? `${short(paymentId, 5)} · ${esc ? fmtUsdc(esc.amount) : "—"} kUSD` : "no escrow yet — open one first"}</span>
            </div>
            <div className="actions">
              <div className="actionrow"><span className="a-l">Merchant · Approve Deliverable → Kembali</span><span className="a-note">{deliverableApproved ? "✓ approved" : ""}</span><button className="btn ghost" onClick={approveDeliverable}>Approve</button></div>
              <div className="actionrow"><span className="a-l">Merchant · Fulfill (deliver + get paid)</span><button className="btn accent" onClick={fulfill}>Fulfill</button></div>
              <div className="actionrow"><span className="a-l">Payer · Refund (after window)</span><span className="a-note">{windowLeft}</span><button className="btn ghost" onClick={refund}>Refund</button></div>
              <div className="actionrow"><span className="a-l">Merchant · Cancel</span><button className="btn ghost" onClick={cancel}>Cancel</button></div>
              <div className="actionrow"><span className="a-l">Withdraw Credited Funds</span><button className="btn" onClick={withdraw}>Withdraw</button></div>
              <div className="actionrow"><span className="a-l">Read Status</span><button className="btn ghost" onClick={() => readStatus()}>Read</button></div>
            </div>
          </div>
        )}

        {view === "agent" && (
          <div className="view">
            <div className="agentcard">
              <div className="eyebrow">🤖 Autonomous Protected Buy</div>
              <h2>Agent commerce that can’t be rugged.</h2>
              <p>One click provisions funds and opens a protected purchase. If the seller doesn’t deliver within the window, the agent’s money auto-returns — recourse built into the payment itself.</p>
              <div className="btnrow"><button className="btn accent" onClick={agentBuy}>Run Agent Buy →</button></div>
            </div>
          </div>
        )}

        {view === "faucet" && (
          <div className="view">
            <div className="panel">
              <p className="sub">Free test assets on the deployed DemoUSDC / DemoNFT. Needs a little HSK for gas.</p>
              <div className="actions">
                <div className="actionrow"><span className="a-l">Mint 1000 test kUSD to me</span><span className="a-note">{fmtUsdc(kusd)} kUSD</span><button className="btn accent" onClick={mintKusd}>Mint</button></div>
                <div className="actionrow"><span className="a-l">Mint a demo NFT (be merchant)</span><button className="btn outline" onClick={mintNft}>Mint</button></div>
              </div>
            </div>
          </div>
        )}

        {view === "contract" && (
          <div className="view">
            <div className="panel">
              <div className="label">Kembali address · HashKey mainnet 177</div>
              <div className="addrbox" style={{ margin: ".5rem 0 1.4rem" }}><a href={explorerAddr(ADDR.kembali)} target="_blank" rel="noreferrer">{ADDR.kembali}</a></div>
              <div className="field"><label>Payment id (bytes32) · auto-filled on Open; paste to fulfill / refund</label>
                <input value={paymentId} onChange={(e) => setPaymentId(e.target.value as `0x${string}`)} placeholder="0x…" /></div>
              <div className="tiles" style={{ marginTop: "1.4rem" }}>
                <div className="tile"><div className="tl">Pay token</div><div className="ts" style={{ marginTop: 8 }}>{short(ADDR.demoUsdc)}</div></div>
                <div className="tile"><div className="tl">Deliverable</div><div className="ts" style={{ marginTop: 8 }}>{short(ADDR.demoNft)}</div></div>
                <div className="tile"><div className="tl">Chain</div><div className="ts" style={{ marginTop: 8 }}>HashKey 177</div></div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
