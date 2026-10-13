import { ArrowUpRight } from "lucide-react";
import { FEATURED_PRODUCTS, SHOP_ORIGIN, shopProductUrl } from "@/data/shop.mjs";

export function Shop() {
  return (
    <section aria-labelledby="shop-heading" className="my-12 md:my-16">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 id="shop-heading" className="text-2xl font-semibold text-[var(--foreground)]">From the bench to the everyday.</h2>
          <p className="mt-2 text-sm text-[var(--muted)]">Beckify goods inspired by electrical engineering and math.</p>
        </div>
        <a href={SHOP_ORIGIN} className="inline-flex min-h-11 items-center gap-2 rounded-lg px-3 text-sm text-[var(--accent)] hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4">
          Explore the shop <ArrowUpRight aria-hidden="true" className="h-4 w-4" />
        </a>
      </div>
      <div className="grid gap-5 sm:grid-cols-3">
        {FEATURED_PRODUCTS.map((product) => (
          <a key={product.handle} href={shopProductUrl(product.handle)} className="card-surface group overflow-hidden rounded-2xl transition-colors hover:border-[var(--accent)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--accent)]">
            <img src={product.image} alt={product.alt} width={720} height={720} loading="lazy" decoding="async" className="aspect-square w-full bg-[#eee7db] object-contain" />
            <div className="p-5">
              <h3 className="flex items-center justify-between gap-2 text-base font-medium text-[var(--foreground)]">{product.name}<ArrowUpRight aria-hidden="true" className="h-4 w-4 shrink-0 text-[var(--muted)]" /></h3>
              <p className="mt-2 text-sm leading-relaxed text-[var(--muted)]">{product.description}</p>
            </div>
          </a>
        ))}
      </div>
    </section>
  );
}
