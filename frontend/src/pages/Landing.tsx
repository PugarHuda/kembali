import { useEffect } from "react";
import { Link } from "react-router-dom";
import { ADDR, explorerAddr } from "../lib/kembali";

function useReveal() {
  useEffect(() => {
    const els = document.querySelectorAll(".reveal");
    const io = new IntersectionObserver(
      (ents) => ents.forEach((e) => e.isIntersecting && e.target.classList.add("in")),
      { threshold: 0.12 },
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);
}

export default function Landing() {
  useReveal();
  return (
    <div>
      <header className="topbar">
        <div className="topbar-in">
          <div className="wordmark">Kembali<span className="cn">返</span></div>
          <nav className="topnav">
            <a href="#how">Protocol</a>
            <a href="#why">Why</a>
            <a href="#security">Security</a>
            <Link className="btn" to="/app">Launch App</Link>
          </nav>
        </div>
      </header>

      {/* HERO */}
      <section className="wrap">
        <div className="hero">
          <div className="reveal">
            <div className="eyebrow">Kembali&nbsp;·&nbsp;Escrow Protocol</div>
            <h1>Payments that<br />can come <span className="it">back.</span></h1>
            <p>Kembali protects buyers using programmable escrow. Funds are only released after on-chain delivery — otherwise they automatically return to the payer.</p>
            <div className="cta-row">
              <Link className="btn accent" to="/app">Launch App →</Link>
              <a className="linkline" href="https://github.com/PugarHuda/kembali" target="_blank" rel="noreferrer">Read Whitepaper</a>
            </div>
            <div className="statrow">
              <div>Built on HashKey</div>
              <div>EIP-712 Verified</div>
              <div>Atomic DvP</div>
              <div>Trustless Escrow</div>
            </div>
          </div>
          <div className="reveal dotgrid heropanel">
            <div className="card esccard">
              <div className="ehead">
                <span>Escrow&nbsp;·&nbsp;0x8f21…a4</span>
                <span className="pill"><span className="dot" style={{ background: "#B67A63" }} />Held</span>
              </div>
              <div className="label" style={{ marginTop: 18 }}>Amount in Escrow</div>
              <div className="amt">1,500.00 <small>USDC</small></div>
              <div className="erow"><span className="k">Payer</span><span className="v">0x2c…91</span></div>
              <div className="erow"><span className="k">Merchant</span><span className="v">0x7a…3e</span></div>
              <div className="erow"><span className="k">Deliverable</span><span className="v">DemoNFT #7</span></div>
              <div className="erow"><span className="k">Deadline</span><span className="v">23h 58m</span></div>
              <div className="steps"><span className="on" /><span className="on" /><span /><span /></div>
              <div className="steplbl"><span>Open</span><span>Protected</span><span>Deliver</span><span>Settle</span></div>
              <div className="efoot"><div>Fulfill</div><div>Refund</div></div>
            </div>
            <div className="figcap">Fig.01 — Example escrow (illustration)</div>
          </div>
        </div>
      </section>

      {/* HOW */}
      <section className="sec" id="how">
        <div className="wrap">
          <div className="reveal"><div className="seclabel">02 / Protocol</div><h2 className="sectitle">How it works</h2></div>
          {[
            ["1", "Open Escrow", "Sign an EIP-712 payment mandate. The signed digest becomes the escrow id."],
            ["2", "Funds Protected", "Assets remain safely locked in the contract, pulled from the signer."],
            ["3", "Merchant Delivers", "Delivery of the exact agreed asset is verified on-chain, within the window."],
            ["4", "Release or Refund", "Funds go to the merchant on delivery — or safely return to the payer."],
          ].map(([n, t, b], i) => (
            <div className={"reveal timerow" + (n === "4" ? " accent" : "")} key={n} style={{ transitionDelay: `${i * 0.05}s` }}>
              <div className="num">{n}</div>
              <div><h3>{t}</h3><p>{b}</p></div>
            </div>
          ))}
        </div>
      </section>

      {/* WHY */}
      <section className="sec why" id="why">
        <div className="wrap">
          <div className="reveal"><div className="seclabel">03 / Principles</div><h2 className="sectitle">Why Kembali</h2></div>
          <div className="reveal whygrid">
            {[
              ["i.", "Trustless", "No third-party arbitrator. Because the deliverable is on-chain, “delivered” is a deterministic fact."],
              ["ii.", "Atomic Delivery", "Payment and delivery happen together — atomic DvP. Asset to payer, funds to merchant, in one move."],
              ["iii.", "Funds Return", "Missed the deadline? The money comes back automatically. Recourse without breaking verifiability."],
            ].map(([rn, t, b]) => (
              <div className="whycard" key={rn}><div className="rn">{rn}</div><h3>{t}</h3><p>{b}</p></div>
            ))}
          </div>
        </div>
      </section>

      {/* ARCHITECTURE */}
      <section className="sec">
        <div className="wrap">
          <div className="reveal"><div className="seclabel">04 / System</div><h2 className="sectitle">Architecture</h2></div>
          <div className="reveal arch">
            <span className="node">Wallet</span><span className="ln" />
            <span className="node">Escrow Contract</span><span className="ln" />
            <span className="node">On-chain Verification</span><span className="ln" />
            <span className="node rel">Release</span><span className="node ref">Refund</span>
          </div>
        </div>
      </section>

      {/* SECURITY */}
      <section className="sec security" id="security">
        <div className="wrap">
          <div className="reveal"><div className="seclabel">05 / Security</div><h2 className="sectitle">Verifiable by design</h2></div>
          <div className="reveal secgrid">
            <div><b>EIP-712</b>Signed mandate digests</div>
            <div><b>EIP-1271</b>Smart-wallet & agent signers</div>
            <div><b>HashKey Chain</b>Mainnet 177, compliant L2</div>
            <div><b>Immutable Contracts</b>Bytecode == audited source</div>
            <div><b>On-chain Verify</b>Canonical HSP, no oracle</div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="wrap">
        <div className="cta-center reveal">
          <div className="seclabel">06 / Launch</div>
          <h2>Open your first reversible payment.</h2>
          <p>Connect a wallet, hold funds in escrow against an on-chain deliverable, and take them back if delivery never comes.</p>
          <Link className="btn accent" to="/app">Launch App →</Link>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="wrap">
        <div className="footgrid">
          <div>
            <div className="wordmark">Kembali<span className="cn">.</span></div>
            <p style={{ color: "var(--body)", maxWidth: "30ch", marginTop: "1rem" }}>Reversible stablecoin payments on HashKey Chain. The money returns.</p>
          </div>
          <div>
            <h4>Protocol</h4>
            <a href="#how">How it works</a><a href="#why">Why Kembali</a><a href="#security">Security</a>
          </div>
          <div>
            <h4>Resources</h4>
            <Link to="/app">Launch App</Link>
            <a href="https://github.com/PugarHuda/kembali" target="_blank" rel="noreferrer">GitHub</a>
            <a href={explorerAddr(ADDR.kembali)} target="_blank" rel="noreferrer">Explorer</a>
          </div>
        </div>
        <div className="foot-copy"><span>© 2026 Kembali</span><span>{ADDR.kembali}</span></div>
      </footer>
    </div>
  );
}
