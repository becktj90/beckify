import { NumberBlocks } from "@/components/games/NumberBlocks";
import { SchemaHead, videoGameSchema } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

export default function NumberBlocksPage() {
  return (
    <>
      <SchemaHead
        title={PAGE_SEO["/games/number-blocks"].title}
        description={PAGE_SEO["/games/number-blocks"].description}
        path="/games/number-blocks"
        schema={videoGameSchema(
          "Number Blocks",
          PAGE_SEO["/games/number-blocks"].description,
          "/games/number-blocks",
        )}
      />
      <NumberBlocks />
    </>
  );
}
