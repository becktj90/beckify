// Change only this origin after Shopify verifies the custom domain and HTTPS.
export const SHOP_ORIGIN = "https://shop.beckify.com";
export const shopProductUrl = (handle) => `${SHOP_ORIGIN}/products/${handle}`;

export const FEATURED_PRODUCTS = [
  {
    name: "Complex Feelings Hoodie",
    handle: "i-have-complex-feelings-hoodie-electrical-engineer-hoodie",
    description: "A Smith chart, a small heart, a warmer layer.",
    image: "https://cdn.shopify.com/s/files/1/0762/4222/3193/files/12532887052928496027_4096.jpg?v=1791912694&width=720",
    alt: "Black Complex Feelings hoodie with Smith chart artwork",
  },
  {
    name: "Complex Feelings Mug",
    handle: "i-have-complex-feelings-mug-electrical-engineer-coffee-mug",
    description: "Complex impedance for the coffee break.",
    image: "https://cdn.shopify.com/s/files/1/0762/4222/3193/files/12190990113496355157_2048.jpg?v=1791900784&width=720",
    alt: "White Complex Feelings mug with Smith chart and heart artwork",
  },
  {
    name: "Control Systems Desk Mat",
    handle: "classical-control-systems-desk-reference-mat-31-5-controls-engineer-desk-pad",
    description: "Feedback, stability, and the reference within reach.",
    image: "https://cdn.shopify.com/s/files/1/0762/4222/3193/files/9739337403410944806_2048.jpg?v=1791901386&width=720",
    alt: "Classical control systems reference desk mat",
  },
];
