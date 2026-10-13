import { useEffect } from "react";
import { SHOP_ORIGIN } from "@/data/shop.mjs";

export function StoreRedirect() {
  useEffect(() => { window.location.replace(SHOP_ORIGIN); }, []);
  return <p className="p-8">Opening the Beckify shop… <a href={SHOP_ORIGIN} className="underline">Continue to the shop</a></p>;
}
