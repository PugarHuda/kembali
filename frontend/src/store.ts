import { create } from "zustand";

interface S {
  paymentId: `0x${string}` | "";
  setPaymentId: (id: `0x${string}` | "") => void;
  deliverableApproved: boolean;
  setDeliverableApproved: (v: boolean) => void;
  toast: string | null;
  flash: (m: string) => void;
}
let t: ReturnType<typeof setTimeout>;
export const useStore = create<S>((set) => ({
  paymentId: "",
  setPaymentId: (id) => set({ paymentId: id }),
  deliverableApproved: false,
  setDeliverableApproved: (v) => set({ deliverableApproved: v }),
  toast: null,
  flash: (m) => {
    set({ toast: m });
    clearTimeout(t);
    t = setTimeout(() => set({ toast: null }), 2800);
  },
}));
