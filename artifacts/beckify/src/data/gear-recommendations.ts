export type GearCategory =
  | "Tools and supplies"
  | "Test equipment"
  | "Cable and fault location"
  | "Job comfort and power";

export type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  bestFor: string;
  note: string;
  amazonUrl: string;
  manufacturerUrl: string;
  imageUrl?: string;
  budget?: boolean;
  usaMade?: boolean;
  /** How we confirmed U.S. manufacturing — shown on the made-in-America page. */
  usaMadeSource?: string;
  certification?: string;
};

export const GEAR_RECOMMENDATIONS: Gear[] = [
  {
    category: "Tools and supplies",
    name: "Daniels Manufacturing AF8",
    model: "M22520/1-01 crimp frame",
    bestFor: "Qualified machined-contact crimping with the approved turret or positioner.",
    note: "Match the contact family, setting, locator, and work instruction.",
    amazonUrl: "https://www.amazon.com/dp/B09CV54JPN?tag=beckify-20",
    manufacturerUrl: "https://dmctools.com/af8-af8",
    imageUrl:
      "https://dmctools.com/media/catalog/product/a/f/af8_without_turret_2_1.jpg?optimize=high&bg-color=255,255,255&fit=bounds&height=1200&width=1800&canvas=1800:1200",
    usaMade: true,
    usaMadeSource: "Daniels Manufacturing designs and builds crimp tools in Orlando, Florida.",
  },
  {
    category: "Tools and supplies",
    name: "KNIPEX EvoStrip",
    model: "Automatic wire stripper",
    bestFor: "Repeatable conductor preparation in its specified range.",
    note: "Confirm conductor size, insulation type, and strip length first.",
    amazonUrl: "https://www.amazon.com/dp/B000R895YM?tag=beckify-20",
    manufacturerUrl: "https://www.knipex.com/evostrip",
  },
  {
    category: "Tools and supplies",
    name: "Klein Tools 11055",
    model: "Wire stripper and cutter",
    bestFor: "Everyday copper-conductor stripping and cutting.",
    note: "A practical general wiring tool, not qualified contact-crimp tooling.",
    amazonUrl: "https://www.amazon.com/dp/B00080DPNQ?tag=beckify-20",
    manufacturerUrl:
      "https://www.kleintools.com/catalog/wire-strippers-cutters-and-crimpers/wire-stripper-and-cutter-self-opening",
    imageUrl: "https://media.kleintools.io/images/original/klein/11055ep_mb.jpg",
    budget: true,
    usaMade: true,
    usaMadeSource: "Klein Tools manufactures the majority of its hand tools in U.S. plants, including this stripper line.",
  },
  {
    category: "Tools and supplies",
    name: "Klein Tools 63050",
    model: "High-leverage cable cutter",
    bestFor: "Clean copper, aluminum, and communications-cable cuts before termination.",
    note: "Verify capacity; never use on energized cable.",
    amazonUrl: "https://www.amazon.com/dp/B0000302X1?tag=beckify-20",
    manufacturerUrl: "https://www.kleintools.com/catalog/standard-cable-cutters/cable-cutter",
    imageUrl: "https://media.kleintools.io/images/original/klein/63050_b_mb.jpg",
    usaMade: true,
    usaMadeSource: "Klein Tools manufactures the majority of its hand tools in U.S. plants, including this cable cutter.",
  },
  {
    category: "Tools and supplies",
    name: "Wiha TorqueVario-S 28506",
    model: "Adjustable 10-50 in-lb torque driver",
    bestFor: "Controlled low-torque fastening on terminals and electronics hardware.",
    note: "Set torque from approved assembly data.",
    amazonUrl: "https://www.amazon.com/dp/B002QV0FCY?tag=beckify-20",
    manufacturerUrl: "https://www.wihatools.com/products/adjustable-torquevario-10-50-in-lbs",
    imageUrl: "https://www.wihatools.com/cdn/shop/files/xj95dmdb06vc5pvonoun_165x.jpg?v=1776759870",
  },
  {
    category: "Tools and supplies",
    name: "Scotch Super 33+",
    model: "3/4 in x 66 ft vinyl electrical tape",
    bestFor: "A durable general-purpose tape for electrical insulation and harness finishing.",
    note: "Use the approved splice or termination method; tape is not a substitute for it.",
    amazonUrl: "https://www.amazon.com/dp/B01N3D2AFK?tag=beckify-20",
    manufacturerUrl: "https://www.scotchbrand.com/3M/en_US/p/d/b10014694/",
    imageUrl:
      "https://multimedia.3m.com/mws/media/2183449J/scotch-super-33-vinyl-electrical-tape-6132-ba-10-3-4-in-x-66-ft-x-0-007-in.jpg",
    usaMade: true,
    usaMadeSource: "3M manufactures Scotch Super 33+ electrical tape in the United States.",
  },
  {
    category: "Tools and supplies",
    name: "CHANNELLOCK 338CB",
    model: "8 in high-leverage diagonal cutting pliers",
    bestFor: "General cutting where durable, comfortable hand pliers are needed.",
    note: "Not an insulated tool or a substitute for an approved cable cutter.",
    amazonUrl: "https://www.amazon.com/dp/B00004SBDD?tag=beckify-20",
    manufacturerUrl: "https://www.channellock.com/product/338cb/",
    imageUrl:
      "https://shop.channellock.com/cdn/shop/files/mjounbwkqrojuu6r5fnr.jpg?v=1776571515&width=1946",
    usaMade: true,
    usaMadeSource: "CHANNELLOCK manufactures pliers in Meadville, Pennsylvania.",
  },
  {
    category: "Test equipment",
    name: "Fluke 87V",
    model: "True-RMS industrial multimeter",
    bestFor: "Primary voltage, resistance, continuity, and frequency troubleshooting.",
    note: "Prove the meter on a known source before and after a critical test.",
    amazonUrl: "https://www.amazon.com/dp/B0002YFD1K?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v",
    imageUrl:
      "https://media.fluke.com/2725d18d-633b-40b2-b09b-b108002e4d59_product_slideshow_main.jpg",
  },
  {
    category: "Test equipment",
    name: "Fluke 117",
    model: "Electrician's True-RMS multimeter",
    bestFor: "Routine building electrical measurements where LoZ helps reduce ghost voltages.",
    note: "Use leads and the meter only within their marked category and voltage rating.",
    amazonUrl: "https://www.amazon.com/dp/B000O3LUEI?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-117",
    imageUrl:
      "https://media.fluke.com/e55511c8-92e6-46b2-b9ae-b108002dd7fa_product_slideshow_main.jpg",
  },
  {
    category: "Test equipment",
    name: "Klein Tools MM400",
    model: "Auto-ranging 600 V digital multimeter",
    bestFor: "Cost-conscious general electrical measurement in its marked CAT III 600 V scope.",
    note: "Check supplied leads, fuses, category rating, and procedure before use.",
    amazonUrl: "https://www.amazon.com/dp/B018EXZO8M?tag=beckify-20",
    manufacturerUrl: "https://www.kleintools.com/catalog/multimeters/digital-multimeter-auto-ranging-600v",
    budget: true,
  },
  {
    category: "Test equipment",
    name: "Fluke T6-1000",
    model: "FieldSense electrical tester",
    bestFor: "Fast AC voltage and current checks at distribution equipment.",
    note: "Use it within the approved test process, not as a substitute for procedure.",
    amazonUrl: "https://www.amazon.com/dp/B076DYBHCW?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/basic-testers/fluke-t6-1000",
    imageUrl:
      "https://media.fluke.com/ae8642ff-0c76-4599-9474-b108002f3377_original__size.jpg",
  },
  {
    category: "Test equipment",
    name: "Fluke 2AC Alert",
    model: "90-1000 V AC non-contact voltage tester",
    bestFor: "A preliminary indication of AC voltage presence.",
    note: "A non-contact tester cannot establish absence of voltage on its own.",
    amazonUrl: "https://www.amazon.com/dp/B004I9J4DI?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/basic-testers/fluke-2ac",
    imageUrl:
      "https://media.fluke.com/dfad1ec3-0a3e-41b4-9b30-b108002e051b_original__size.jpg",
  },
  {
    category: "Test equipment",
    name: "Klein Tools NCVT2P",
    model: "Dual-range non-contact voltage tester",
    bestFor: "Quick AC presence checks before a complete test.",
    note: "Verify operation on a known live source first.",
    amazonUrl: "https://www.amazon.com/dp/B07L5N8ZWS?tag=beckify-20",
    manufacturerUrl:
      "https://www.kleintools.com/catalog/electrical-testers/non-contact-voltage-tester-pen-dual-range-12-1000v-ac-or-48-1000v-ac",
    imageUrl: "https://media.kleintools.io/images/original/klein/ncvt-2.jpg",
  },
  {
    category: "Test equipment",
    name: "Klein Tools ET310",
    model: "Circuit-breaker finder with GFCI tester",
    bestFor: "Locating a 90-120 V branch-circuit breaker and checking a grounded receptacle.",
    note: "It is not a switchgear fault-investigation instrument.",
    amazonUrl: "https://www.amazon.com/dp/B07QNMCVWP?tag=beckify-20",
    manufacturerUrl:
      "https://www.kleintools.com/catalog/electrical-testers/digital-circuit-breaker-finder-gfci-outlet-tester",
    imageUrl: "https://media.kleintools.io/images/original/klein/et310_c.jpg",
    budget: true,
  },
  {
    category: "Test equipment",
    name: "Fluke 62 MAX+",
    model: "Dual-laser IR thermometer",
    bestFor: "Screening energized equipment for abnormal temperature.",
    note: "Emissivity, distance, loading, and follow-up measurement determine whether a finding matters.",
    amazonUrl: "https://www.amazon.com/dp/B0089N2ZH6?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/temperature-measurement/ir-thermometers/fluke-62-max-plus",
    imageUrl:
      "https://media.fluke.com/44da1b0d-d6a9-473c-95e7-b108005a2ed6_original__size.jpg",
  },
  {
    category: "Test equipment",
    name: "FLIR C5",
    model: "160 x 120 compact thermal camera",
    bestFor: "Documenting thermal anomalies on panels, terminations, motors, and equipment under load.",
    note: "A thermal image identifies a condition to investigate, not the root cause.",
    amazonUrl: "https://www.amazon.com/dp/B0892MZZT1?tag=beckify-20",
    manufacturerUrl: "https://www.flir.com/products/c5/",
    imageUrl: "https://www.flir.com/netx-assets/c5-wifi-2-view-01/?width=1500&quality=80",
  },
  {
    category: "Test equipment",
    name: "Fluke 1507",
    model: "50 V to 1000 V insulation resistance tester",
    bestFor: "Specified insulation-resistance workflows on wiring and electrical equipment.",
    note: "Test voltage, isolation, discharge, and acceptance criteria come from the procedure.",
    amazonUrl: "https://www.amazon.com/dp/B000X4O9WI?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/insulation-testers/fluke-1507",
    imageUrl:
      "https://media.fluke.com/2882fbd6-a477-4823-8210-b108002ddc22_product_slideshow_main.jpg",
  },
  {
    category: "Test equipment",
    name: "Klein Tools ET600",
    model: "1000 V insulation resistance tester",
    bestFor: "Insulation, continuity, and voltage measurements in electrical maintenance.",
    note: "Never insulation-test an energized circuit.",
    amazonUrl: "https://www.amazon.com/dp/B07ZZX5TK8?tag=beckify-20",
    manufacturerUrl: "https://www.kleintools.com/catalog/multimeters/insulation-resistance-tester",
    imageUrl: "https://media.kleintools.io/images/original/klein/et600_d.jpg",
  },
  {
    category: "Test equipment",
    name: "Fluke 376 FC",
    model: "True-RMS AC/DC clamp meter with iFlex",
    bestFor: "Current checks around conductors where a fixed jaw cannot reach.",
    note: "Confirm conductor placement and method before interpreting the result.",
    amazonUrl: "https://www.amazon.com/dp/B017OVC2QM?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-376-fc",
    imageUrl:
      "https://media.fluke.com/2349e539-9d7a-457b-b8ea-b108002e1bc3_product_slideshow_main.jpg",
  },
  {
    category: "Test equipment",
    name: "Klein Tools CL120",
    model: "400 A AC auto-ranging clamp meter",
    bestFor: "Cost-conscious AC-current, voltage, resistance, and continuity checks.",
    note: "This clamp measures AC current only; confirm the function before use.",
    amazonUrl: "https://www.amazon.com/dp/B08CP6GL49?tag=beckify-20",
    manufacturerUrl: "https://www.kleintools.com/catalog/clamp-meters/digital-clamp-meter-ac-auto-ranging-400-amp",
    imageUrl: "https://media.kleintools.io/images/original/klein/cl120.jpg",
    budget: true,
  },
  {
    category: "Test equipment",
    name: "Fluke 323",
    model: "True-RMS 400 A AC clamp meter",
    bestFor: "Basic AC-current, voltage, and resistance checks.",
    note: "It measures AC current, not DC current.",
    amazonUrl: "https://www.amazon.com/dp/B00AQKIEXY?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-323",
    imageUrl:
      "https://media.fluke.com/c0eacec0-218d-47a2-9ca4-b108002e0817_original__size.jpg",
  },
  {
    category: "Test equipment",
    name: "Fluke 771",
    model: "Milliamp process clamp meter",
    bestFor: "Measuring 4-20 mA process signals without opening the loop.",
    note: "Confirm loop configuration and access requirements before clamping.",
    amazonUrl: "https://www.amazon.com/dp/B000R81ARM?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/calibration-tools/ma-loop-calibrators/fluke-771",
    imageUrl:
      "https://media.fluke.com/78209300-b37f-4cb3-b32b-b108002bcc4e_original__size.jpg",
  },
  {
    category: "Test equipment",
    name: "RIGOL DHO804",
    model: "Four-channel 70 MHz digital oscilloscope",
    bestFor: "Bench diagnostics for power rails, clocks, data, and control signals.",
    note: "Probe selection and grounding still matter.",
    amazonUrl: "https://www.amazon.com/dp/B0CGHQHQN7?tag=beckify-20",
    manufacturerUrl: "https://mall.rigol.com/shiboqi/dho804.html",
    imageUrl: "https://alc-sh-ecdata.oss-cn-shanghai.aliyuncs.com/8bb32098ca4440fd4f0590a89456b23f.png",
  },
  {
    category: "Test equipment",
    name: "RIGOL DS1054Z",
    model: "Four-channel 50 MHz digital oscilloscope",
    bestFor: "General embedded, control, and low-to-mid-speed waveform troubleshooting.",
    note: "Never create a fault path with a grounded probe.",
    amazonUrl: "https://www.amazon.com/dp/B012938E76?tag=beckify-20",
    manufacturerUrl: "https://www.rigolna.com/products/digital-oscilloscopes/ds1000z/",
    imageUrl: "https://www.rigolna.com/images/products/1000Z.jpg",
    budget: true,
  },
  {
    category: "Test equipment",
    name: "SIGLENT SDS1104X-E",
    model: "Four-channel 100 MHz digital oscilloscope",
    bestFor: "Electronics work that benefits from more bandwidth and signal comparison.",
    note: "Verify probe compensation, attenuation, and ground reference first.",
    amazonUrl: "https://www.amazon.com/dp/B0771N1ZF9?tag=beckify-20",
    manufacturerUrl: "https://siglentna.com/product/sds1104x-e-100-mhz/",
    imageUrl: "https://siglentna.com/wp-content/uploads/2019/06/SDS1204XE4.jpg",
  },
  {
    category: "Test equipment",
    name: "Fluke 289",
    model: "True-RMS logging multimeter with TrendCapture",
    bestFor: "Finding intermittent behavior through logged measurements.",
    note: "Use logs to support a diagnostic plan, not to replace required calibration.",
    amazonUrl: "https://www.amazon.com/dp/B0012B51HI?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-289",
    imageUrl:
      "https://media.fluke.com/754f67ca-87e2-4668-bbff-b108002c0c74_product_slideshow_main.jpg",
  },
  {
    category: "Cable and fault location",
    name: "Megger TDR500/3",
    model: "Handheld cable fault locator",
    bestFor: "Locating opens, shorts, and distance-to-fault on de-energized metallic cable.",
    note: "Isolate and de-energize the cable before connecting a TDR.",
    amazonUrl: "https://www.amazon.com/dp/B00EPLIEJO?tag=beckify-20",
    manufacturerUrl: "https://www.megger.com/",
  },
  {
    category: "Cable and fault location",
    name: "Klein Tools Scout Pro 3",
    model: "VDV501-851 cable tester kit",
    bestFor: "Identifying and mapping Ethernet, telephone, and coaxial cable runs.",
    note: "It is a verifier, not a certification instrument.",
    amazonUrl: "https://www.amazon.com/dp/B085LPN71C?tag=beckify-20",
    manufacturerUrl:
      "https://www.kleintools.com/catalog/cable-length-measurement/ethernet-cable-tester-kit-scout-pro-3-tester-remotes-and-adapter",
    imageUrl: "https://media.kleintools.io/images/original/klein/vdv501851.jpg",
  },
  {
    category: "Cable and fault location",
    name: "Fluke Networks MicroScanner PoE",
    model: "MS-POE copper cable verifier",
    bestFor: "PoE, wiremap, length, switch capability, and distance-to-fault checks.",
    note: "For supported copper Ethernet systems only.",
    amazonUrl: "https://www.amazon.com/dp/B07NJMKG9L?tag=beckify-20",
    manufacturerUrl: "https://www.fluke.com/en-us/product/network-cable-testers/copper/ms-poe",
    imageUrl:
      "https://media.fluke.com/e71c868e-ddf4-47b1-94d0-b108002c98bf_original__size.jpg",
  },
  {
    category: "Cable and fault location",
    name: "AURSINC NanoVNA-H4",
    model: "9 kHz to 1.5 GHz portable vector network analyzer",
    bestFor: "Antenna, coax, impedance, and return-loss investigation.",
    note: "Not a calibrated replacement where traceability is required.",
    amazonUrl: "https://www.amazon.com/dp/B07T6LXNTV?tag=beckify-20",
    manufacturerUrl: "https://nanovna.com/",
    budget: true,
  },
  {
    category: "Job comfort and power",
    name: "EcoFlow DELTA Pro 3",
    model: "4096 Wh portable power station",
    bestFor: "Quiet jobsite, outage, and remote-work power where portable 120/240 V capacity is appropriate.",
    note: "EcoFlow describes this model as UL 9540 certified. Verify the current label, configuration, and local requirements before installation.",
    amazonUrl: "https://www.amazon.com/dp/B0D14FMFZD?tag=beckify-20",
    manufacturerUrl: "https://us.ecoflow.com/products/delta-pro-3-portable-power-station",
    imageUrl:
      "https://us.ecoflow.com/cdn/shop/files/ecoflow-ecoflow-delta-pro-3-portable-power-station-ul9540-certificated-dp3-delta-pro-3-1179495742.png?v=1762761450",
    certification: "UL 9540 certified",
  },
  {
    category: "Job comfort and power",
    name: "SeeDevil 150 W Balloon Light Kit",
    model: "150 W, 19,500 lm portable area light",
    bestFor: "Glare-reduced, wide-area task lighting for night work and temporary sites.",
    note: "Plan the 120 V feed, tripod placement, and required site lighting controls.",
    amazonUrl: "https://www.amazon.com/dp/B081277RB5?tag=beckify-20",
    manufacturerUrl: "https://seedevil.com/products/g3-150-watt-balloon-light-kit",
    imageUrl:
      "https://seedevil.com/cdn/shop/files/00B_f48d8ef3-ec74-4aaf-ae98-a32407c8bdaa.png?v=1700465376&width=2048",
  },
  {
    category: "Job comfort and power",
    name: "BougeRV 23 Quart Portable Fridge",
    model: "12 V compressor cooler",
    bestFor: "Keeping food, drinks, or permitted temperature-sensitive supplies cold on long field days.",
    note: "Use the supplied power arrangement and protect the vehicle battery.",
    amazonUrl: "https://www.amazon.com/dp/B08G1BBBQW?tag=beckify-20",
    manufacturerUrl: "https://www.bougerv.com/products/12v-23-quart-portable-refrigerator-for-travel",
    imageUrl:
      "https://www.bougerv.com/cdn/shop/files/12V_23_Quart_Portable_Car_Fridge_For_Travel.png?v=1747298711",
  },
  {
    category: "Job comfort and power",
    name: "HOTLIGH Magnetic Flashlight",
    model: "ZF6771 rechargeable magnetic work light",
    bestFor: "Close-up, hands-free light at panels, cabinets, and service points.",
    note: "This is convenience lighting, not a hazardous-location light.",
    amazonUrl: "https://www.amazon.com/dp/B0D66SHL2C?tag=beckify-20",
    manufacturerUrl: "https://hotligh.com/products/rechargeable-flashlight-zf6771",
    imageUrl:
      "https://hotligh.com/cdn/shop/files/1_691e0051-f8ca-4935-8878-1a4673d46b1c.jpg?v=1766332565",
  },
  {
    category: "Job comfort and power",
    name: "TORRAS COOLiFY 2S",
    model: "Wearable neck air conditioner",
    bestFor: "Personal cooling during hot outdoor, rooftop, and vehicle work.",
    note: "Treat it as comfort gear; maintain heat-stress breaks, hydration, and the site plan.",
    amazonUrl: "https://www.amazon.com/dp/B0BY9271YQ?tag=beckify-20",
    manufacturerUrl: "https://coolify.torraslife.com/collections/all-products",
    imageUrl:
      "https://coolify.torraslife.com/cdn/shop/files/2s_561b1271-e524-4b09-8d46-13c891512e5f.png?v=1772773370&width=300",
  },
];

export const USA_MADE_GEAR = GEAR_RECOMMENDATIONS.filter((item) => item.usaMade);

export const USA_MADE_BRANDS = [
  { name: "Klein Tools", note: "Hand tools and strippers from U.S. plants" },
  { name: "CHANNELLOCK", note: "Pliers forged in Meadville, Pennsylvania" },
  { name: "Daniels Manufacturing", note: "Aerospace crimp tools built in Florida" },
  { name: "3M Scotch", note: "Super 33+ tape made in the United States" },
] as const;

export const MADE_IN_AMERICA_FAQ = [
  {
    question: "What electrical tools are made in America?",
    answer:
      "American-made electrical hand tools include Klein strippers and cable cutters, CHANNELLOCK pliers, Daniels crimp frames, and 3M Scotch Super 33+ tape. This guide lists verified model numbers with direct manufacturer links so you can confirm origin before buying.",
  },
  {
    question: "How do you verify a product is American-made?",
    answer:
      "We only list items where the manufacturer publicly identifies U.S. manufacturing for that specific product line. Check the product page, packaging country-of-origin label, and manufacturer’s American manufacturing statement. A U.S. brand name alone is not enough.",
  },
  {
    question: "Are Klein Tools made in the USA?",
    answer:
      "Most Klein hand tools — pliers, cutters, strippers, and similar forged tools — are manufactured in U.S. plants. Klein also sells test equipment and accessories that may be sourced globally, so verify the specific model before assuming U.S. origin.",
  },
  {
    question: "Why isn’t every recommended tool on this list?",
    answer:
      "This is a conservative, field-tested shortlist — not a directory of every American-made electrical product. We prioritize tools electricians actually use daily and only include items we can trace to a clear U.S. manufacturing claim.",
  },
] as const;
