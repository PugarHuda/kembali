import { Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing";
import DApp from "./pages/DApp";
import { useStore } from "./store";

function Toast() {
  const toast = useStore((s) => s.toast);
  if (!toast) return null;
  return <div className="toast">{toast}</div>;
}

export default function App() {
  return (
    <>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/app" element={<DApp />} />
        <Route path="*" element={<Landing />} />
      </Routes>
      <Toast />
    </>
  );
}
