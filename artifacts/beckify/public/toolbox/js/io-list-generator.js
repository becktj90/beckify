/* ============================================================================
   I/O LIST GENERATOR
   ============================================================================
   Scaffold a PLC I/O list from a per-station brand catalog or from generic
   channel counts. Couplers, adapters, CPUs, and power-refresh cards consume a
   slot and emit one documentation row even with zero channels.

   A station is one brand unless the user explicitly allows mixed catalogs.
   Multiple stations in one project may use different brands, including a
   "No brand / generic" counts mode.

   Design aid only. Not a PE stamp, not a wiring schedule, not a submittal.
   Seed part numbers are public catalog examples — verify against the vendor
   datasheet before using a file in a project.
   ============================================================================ */

(function (global) {
  'use strict';

  const COLUMNS = [
    'Controller',
    'Card Name',
    'Card Part Number',
    'Station Name',
    'Slot Number',
    'Channel Number',
    'Wire Terminal',
    'Wire Number',
    'Linked PLC Variable Name',
    'Description',
    'System',
    'Device Category',
    'Signal Type',
    'Min',
    'Max',
    'Units',
    'Raw Min',
    'Raw Max',
    'Page',
    'Field Device',
    'Intermediate Device',
    'EPLAN Updated',
    'Electrical Check Complete',
    'Scaling Verified',
    'T&LO V&V',
    'Comments',
  ];

  const BLANK_ON_GENERATE = [
    'Wire Number',
    'Linked PLC Variable Name',
    'Description',
    'System',
    'Device Category',
    'Page',
    'Field Device',
    'Intermediate Device',
    'EPLAN Updated',
    'Electrical Check Complete',
    'Scaling Verified',
    'T&LO V&V',
    'Comments',
  ];

  const GENERIC_TYPES = [
    { key: 'DI', label: 'Generic DI', signalType: 'DI', density: 16 },
    { key: 'DO', label: 'Generic DO', signalType: 'DO', density: 8 },
    { key: 'AI', label: 'Generic AI', signalType: 'AI (4-20mA)', density: 8, rawMin: '6554', rawMax: '32767', bits: '16' },
    { key: 'AO', label: 'Generic AO', signalType: 'AO (4-20mA)', density: 4, rawMin: '6554', rawMax: '32767', bits: '16' },
    { key: 'RTD', label: 'Generic RTD', signalType: 'RTD', density: 4, rawMin: '0', rawMax: '32767', bits: '16' },
    { key: 'TC', label: 'Generic TC', signalType: 'TC', density: 8, rawMin: '-32768', rawMax: '32767', bits: '16' },
    { key: 'IOLINK', label: 'Generic IO-Link', signalType: 'IO-Link', density: 4 },
  ];

  const XLSX_SRC = 'js/vendor/xlsx.full.min.js';

  /* Pastel fills + dark text for a white Excel sheet. HTML uses separate
     dark-theme tints in CSS (.iol-sig-*). */
  const TYPE_COLORS = {
    DI: { html: 'iol-sig-di', fill: 'C5D8F0', font: '1A365D' },
    DO: { html: 'iol-sig-do', fill: 'FBD38D', font: '7B341E' },
    AI: { html: 'iol-sig-ai', fill: 'C6F6D5', font: '22543D' },
    'AI-V': { html: 'iol-sig-ai-v', fill: '9AE6B4', font: '22543D' },
    AO: { html: 'iol-sig-ao', fill: 'B2F5EA', font: '234E52' },
    RTD: { html: 'iol-sig-rtd', fill: 'E9D8FD', font: '44337A' },
    TC: { html: 'iol-sig-tc', fill: 'D6BCFA', font: '44337A' },
    'IO-Link': { html: 'iol-sig-iolink', fill: 'FED7E2', font: '702459' },
    coupler: { html: 'iol-sig-coupler', fill: 'E2E8F0', font: '2D3748' },
    power: { html: 'iol-sig-power', fill: 'FED7D7', font: '822727' },
    other: { html: 'iol-sig-other', fill: 'EDF2F7', font: '1A202C' },
  };

  const HEADER_STYLE = { fill: '2D3748', font: 'F7FAFC' };

  const BRANDS = [
    { id: 'generic', label: 'No brand / generic (counts only)', prefixes: { coupler: 'CPL', io: 'IO', power: 'PWR' } },
    { id: 'beckhoff-ethercat', label: 'Beckhoff EtherCAT', prefixes: { coupler: 'KFD', io: 'KEC', power: 'XDC' } },
    { id: 'ra-1756', label: 'Rockwell ControlLogix 1756', prefixes: { coupler: 'EN', io: 'M', power: 'PS' } },
    { id: 'ra-5069', label: 'Rockwell CompactLogix / 5069', prefixes: { coupler: 'ADP', io: 'M', power: 'PWR' } },
    { id: 'ra-1734', label: 'Rockwell POINT I/O 1734', prefixes: { coupler: 'AENT', io: 'POINT', power: 'PWR' } },
    { id: 'siemens-et200sp', label: 'Siemens ET 200SP', prefixes: { coupler: 'IM', io: 'SM', power: 'PM' } },
    { id: 'siemens-s71500', label: 'Siemens S7-1500', prefixes: { coupler: 'CPU', io: 'SM', power: 'PS' } },
    { id: 'schneider-modicon', label: 'Schneider Modicon TM3 / M580', prefixes: { coupler: 'BC', io: 'TM3', power: 'PWR' } },
    { id: 'wago-750', label: 'WAGO 750', prefixes: { coupler: 'BK', io: '750', power: 'PWR' } },
    { id: 'phoenix-axioline', label: 'Phoenix Contact Axioline F', prefixes: { coupler: 'BK', io: 'AXL', power: 'PWR' } },
    { id: 'omron-nx', label: 'Omron NX', prefixes: { coupler: 'ECC', io: 'NX', power: 'PWR' } },
    { id: 'mitsubishi-iqr', label: 'Mitsubishi iQ-R', prefixes: { coupler: 'CPU', io: 'R', power: 'PWR' } },
    { id: 'ad-productivity', label: 'AutomationDirect Productivity', prefixes: { coupler: 'CPU', io: 'P3', power: 'PWR' } },
  ];

  const R16_420 = { rawMin: '6554', rawMax: '32767', bits: '16' };
  const R16_020 = { rawMin: '0', rawMax: '32767', bits: '16' };
  const R12 = { rawMin: '0', rawMax: '4095', bits: '12' };
  const R_S7 = { rawMin: '0', rawMax: '27648', bits: '15' };
  const R_AD = { rawMin: '0', rawMax: '65535', bits: '16' };

  function M(brand, pn, description, channels, signalType, extra) {
    extra = extra || {};
    return {
      brand: brand,
      pn: pn,
      description: description,
      channels: channels,
      signalType: signalType,
      rawMin: extra.rawMin !== undefined ? String(extra.rawMin) : '',
      rawMax: extra.rawMax !== undefined ? String(extra.rawMax) : '',
      widthMm: extra.widthMm !== undefined ? String(extra.widthMm) : '',
      ebusMa: extra.ebusMa !== undefined ? String(extra.ebusMa) : '',
      bits: extra.bits !== undefined ? String(extra.bits) : '',
    };
  }

  /* Representative public catalog numbers only. Not a vendor price book.
     Beckhoff E-bus mA are typical published E-bus consumption (negative =
     draw) or coupler/refresh supply (positive). Other brands leave mA blank
     unless a public figure is obvious — fill from the datasheet. */
  const SEED_CATALOG = [
    M('beckhoff-ethercat', 'EK1100', 'EtherCAT Coupler RJ45 (E-bus supply typically 2000 mA)', 0, 'Coupler', { widthMm: '44', ebusMa: '2000' }),
    M('beckhoff-ethercat', 'EK1110', 'EtherCAT Extension RJ45', 0, 'Coupler', { widthMm: '44', ebusMa: '-220' }),
    M('beckhoff-ethercat', 'EL9410', 'E-bus / Power Refresh (new E-bus segment, typically 2000 mA)', 0, 'Power', { widthMm: '12', ebusMa: '2000' }),
    M('beckhoff-ethercat', 'EL1819', '16ch DI 24VDC', 16, 'DI', { widthMm: '12', ebusMa: '-100' }),
    M('beckhoff-ethercat', 'EL2828', '8ch DO 24VDC 2A', 8, 'DO', { widthMm: '12', ebusMa: '-140' }),
    M('beckhoff-ethercat', 'EL3048', '8ch AI 0–20mA 12-bit', 8, 'AI (0-20mA)', { widthMm: '12', ebusMa: '-130', rawMin: '0', rawMax: '4095', bits: '12' }),
    M('beckhoff-ethercat', 'EL4022', '2ch AO 4–20mA 16-bit', 2, 'AO (4-20mA)', Object.assign({ widthMm: '12', ebusMa: '-180' }, R16_420)),
    M('beckhoff-ethercat', 'EL4024', '4ch AO 4–20mA 16-bit', 4, 'AO (4-20mA)', Object.assign({ widthMm: '12', ebusMa: '-180' }, R16_420)),
    M('beckhoff-ethercat', 'EL3068', '8ch AI 0–10V 12-bit', 8, 'AI (0-10V)', { widthMm: '12', ebusMa: '-130', rawMin: '0', rawMax: '4095', bits: '12' }),
    M('beckhoff-ethercat', 'EL3214', '4ch AI RTD Pt100', 4, 'RTD', Object.assign({ widthMm: '12', ebusMa: '-170' }, R16_020)),
    M('beckhoff-ethercat', 'EL3318', '8ch AI thermocouple 16-bit', 8, 'TC', { widthMm: '12', ebusMa: '-200', rawMin: '-32768', rawMax: '32767', bits: '16' }),
    M('beckhoff-ethercat', 'EL6224', '4ch IO-Link master', 4, 'IO-Link', { widthMm: '24', ebusMa: '-120' }),
    M('beckhoff-ethercat', 'EL4122', '2ch AO 0–20mA 16-bit', 2, 'AO (0-20mA)', Object.assign({ widthMm: '12', ebusMa: '-180' }, R16_020)),
    M('beckhoff-ethercat', 'EL4124', '4ch AO 0–20mA 16-bit', 4, 'AO (0-20mA)', Object.assign({ widthMm: '12', ebusMa: '-180' }, R16_020)),
    M('beckhoff-ethercat', 'EL6070', 'TwinCAT license key terminal (0 channels, still a slot)', 0, 'License', { widthMm: '12' }),

    M('ra-1756', '1756-EN2T', 'ControlLogix EtherNet/IP bridge (slot-consuming comms module; not a chassis)', 0, 'Adapter', {}),
    M('ra-1756', '1756-IB16', '16ch 10–30V DC sinking digital input', 16, 'DI', {}),
    M('ra-1756', '1756-OB16', '16ch 10–31.2V DC sourcing digital output', 16, 'DO', {}),
    M('ra-1756', '1756-IF8', '8ch analog input (voltage/current, configurable)', 8, 'AI (4-20mA)', R16_420),
    M('ra-1756', '1756-OF8', '8ch analog output (voltage/current, configurable)', 8, 'AO (4-20mA)', R16_420),
    M('ra-1756', '1756-IRT8I', '8ch isolated RTD/thermocouple input', 8, 'RTD', R16_020),

    M('ra-5069', '5069-AENTR', 'Compact 5000 EtherNet/IP adapter (distributed I/O head)', 0, 'Adapter', {}),
    M('ra-5069', '5069-IB16', '16ch 24V DC sinking digital input', 16, 'DI', {}),
    M('ra-5069', '5069-OB16', '16ch 24V DC sourcing digital output', 16, 'DO', {}),
    M('ra-5069', '5069-IF8', '8ch analog input voltage/current 16-bit', 8, 'AI (4-20mA)', R16_420),
    M('ra-5069', '5069-OF8', '8ch analog output voltage/current 16-bit', 8, 'AO (4-20mA)', R16_420),
    M('ra-5069', '5069-IR8', '8ch RTD/resistance analog input', 8, 'RTD', R16_020),

    M('ra-1734', '1734-AENT', 'POINT I/O EtherNet/IP adapter', 0, 'Adapter', {}),
    M('ra-1734', '1734-IB8', '8ch 24V DC sinking digital input', 8, 'DI', {}),
    M('ra-1734', '1734-OB8', '8ch 24V DC sourcing digital output', 8, 'DO', {}),
    M('ra-1734', '1734-IE2C', '2ch analog current input', 2, 'AI (4-20mA)', R16_420),
    M('ra-1734', '1734-OE2C', '2ch analog current output', 2, 'AO (4-20mA)', R16_420),
    M('ra-1734', '1734-IR2', '2ch RTD input', 2, 'RTD', R16_020),

    M('siemens-et200sp', '6ES7155-6AU01-0BN0', 'IM 155-6 PN ST PROFINET interface module', 0, 'Interface', {}),
    M('siemens-et200sp', '6ES7131-6BH01-0BA0', 'DI 16x24VDC ST', 16, 'DI', {}),
    M('siemens-et200sp', '6ES7132-6BF01-0BA0', 'DQ 8x24VDC/0.5A ST', 8, 'DO', {}),
    M('siemens-et200sp', '6ES7134-6GD01-0BA1', 'AI 4xI 2-/4-wire ST', 4, 'AI (4-20mA)', R_S7),
    M('siemens-et200sp', '6ES7135-6GB00-0BA1', 'AQ 2xI ST', 2, 'AO (4-20mA)', R_S7),
    M('siemens-et200sp', '6ES7134-6JD00-0CA1', 'AI 4xRTD/TC 2-/3-/4-wire HF', 4, 'RTD', R_S7),
    M('siemens-et200sp', '6ES7138-6CB00-0BA0', 'PM-E DC24V ST potential distributor / load-group power', 0, 'Power', {}),

    M('siemens-s71500', '6ES7511-1AK02-0AB0', 'CPU 1511-1 PN (slot-0 equivalent)', 0, 'CPU', {}),
    M('siemens-s71500', '6ES7521-1BL00-0AB0', 'DI 32x24VDC HF', 32, 'DI', {}),
    M('siemens-s71500', '6ES7522-1BL01-0AB0', 'DQ 32x24VDC/0.5A HF', 32, 'DO', {}),
    M('siemens-s71500', '6ES7531-7KF00-0AB0', 'AI 8xU/I/RTD/TC ST', 8, 'AI (4-20mA)', R_S7),
    M('siemens-s71500', '6ES7532-5HD00-0AB0', 'AQ 4xU/I ST', 4, 'AO (4-20mA)', R_S7),

    M('schneider-modicon', 'TM3BCEIP', 'TM3 EtherNet/IP / Modbus TCP bus coupler', 0, 'Coupler', {}),
    M('schneider-modicon', 'TM3DI16', '16ch 24V DC discrete input', 16, 'DI', {}),
    M('schneider-modicon', 'TM3DQ16T', '16ch transistor source discrete output', 16, 'DO', {}),
    M('schneider-modicon', 'TM3AI8', '8ch analog input 12-bit (V/I configurable)', 8, 'AI (4-20mA)', R12),
    M('schneider-modicon', 'TM3AQ4', '4ch analog output 12-bit (V/I configurable)', 4, 'AO (4-20mA)', R12),
    M('schneider-modicon', 'TM3TI4', '4ch temperature input (RTD / TC / analog)', 4, 'RTD', { rawMin: '0', rawMax: '32767', bits: '16' }),

    M('wago-750', '750-363', 'Fieldbus coupler EtherNet/IP (4th gen ECO)', 0, 'Coupler', { widthMm: '50' }),
    M('wago-750', '750-430', '8ch DI 24VDC', 8, 'DI', { widthMm: '12' }),
    M('wago-750', '750-530', '8ch DO 24VDC 0.5A', 8, 'DO', { widthMm: '12' }),
    M('wago-750', '750-454', '2ch AI 4–20mA', 2, 'AI (4-20mA)', Object.assign({ widthMm: '12' }, R16_420)),
    M('wago-750', '750-554', '2ch AO 4–20mA', 2, 'AO (4-20mA)', Object.assign({ widthMm: '12' }, R16_420)),
    M('wago-750', '750-450', '4ch analog input, resistance / RTD', 4, 'RTD', Object.assign({ widthMm: '12' }, R16_020)),
    M('wago-750', '750-602', '24VDC supply module (system / field power)', 0, 'Power', { widthMm: '12' }),

    M('phoenix-axioline', 'AXL F BK ETH', 'Axioline F Modbus/TCP bus coupler (article 2688459)', 0, 'Coupler', {}),
    M('phoenix-axioline', 'AXL F DI16/1 1H', '16ch DI 24VDC 1-wire (article 2688310)', 16, 'DI', {}),
    M('phoenix-axioline', 'AXL F DO8/2 2A 1H', '8ch DO 24VDC 2A 2-wire (article 2688349)', 8, 'DO', {}),
    M('phoenix-axioline', 'AXL F AI4 I 1H', '4ch AI current (article 2688491)', 4, 'AI (4-20mA)', R16_420),
    M('phoenix-axioline', 'AXL F AO4 1H', '4ch analog output (article 2688527)', 4, 'AO (4-20mA)', R16_420),
    M('phoenix-axioline', 'AXL F RTD4 1H', '4ch RTD input (article 2688556)', 4, 'RTD', R16_020),

    M('omron-nx', 'NX-ECC201', 'NX-series EtherCAT coupler unit', 0, 'Coupler', { widthMm: '46' }),
    M('omron-nx', 'NX-ID5442', '16ch DC input PNP', 16, 'DI', { widthMm: '12' }),
    M('omron-nx', 'NX-OD5256', '16ch transistor output PNP', 16, 'DO', { widthMm: '12' }),
    M('omron-nx', 'NX-AD2203', '2ch analog input 4–20mA (1/8000)', 2, 'AI (4-20mA)', { widthMm: '12', rawMin: '0', rawMax: '8000', bits: '13' }),
    M('omron-nx', 'NX-DA2203', '2ch analog output 4–20mA (1/8000)', 2, 'AO (4-20mA)', { widthMm: '12', rawMin: '0', rawMax: '8000', bits: '13' }),
    M('omron-nx', 'NX-TS3101', '4ch RTD input unit', 4, 'RTD', { widthMm: '12', rawMin: '0', rawMax: '32767', bits: '16' }),

    M('mitsubishi-iqr', 'R04CPU', 'MELSEC iQ-R CPU (slot-0 equivalent)', 0, 'CPU', {}),
    M('mitsubishi-iqr', 'RX41C4', '32ch 24VDC input', 32, 'DI', {}),
    M('mitsubishi-iqr', 'RY41NT2P', '32ch transistor sink output', 32, 'DO', {}),
    M('mitsubishi-iqr', 'R60AD8-G', '8ch channel-isolated analog input', 8, 'AI (4-20mA)', R16_420),
    M('mitsubishi-iqr', 'R60DA8-G', '8ch channel-isolated analog output', 8, 'AO (4-20mA)', R16_420),
    M('mitsubishi-iqr', 'R60RD8-G', '8ch channel-isolated RTD input', 8, 'RTD', R16_020),

    M('ad-productivity', 'P3-550E', 'Productivity3000 CPU (controller slot)', 0, 'CPU', {}),
    M('ad-productivity', 'P3-08ND3S', '8ch isolated 12–24VDC sinking/sourcing input', 8, 'DI', {}),
    M('ad-productivity', 'P3-08TD1S', '8ch isolated sinking DC output', 8, 'DO', {}),
    M('ad-productivity', 'P3-08AD', '8ch analog input (V/I configurable)', 8, 'AI (4-20mA)', R_AD),
    M('ad-productivity', 'P3-04DA', '4ch analog output (V or 4–20mA)', 4, 'AO (4-20mA)', R_AD),
    M('ad-productivity', 'P3-08RTD', '8ch RTD analog input', 8, 'RTD', R_AD),
  ];

  let xlsxPromise = null;
  let catalog = cloneCatalog(SEED_CATALOG);
  let stations = [emptyStation(1)];
  let gridRows = [];
  let stationSeq = 1;
  let moduleSeq = 1;
  let catalogBrandFilter = '';

  function brandById(id) {
    const key = String(id || '');
    for (let i = 0; i < BRANDS.length; i++) {
      if (BRANDS[i].id === key) return BRANDS[i];
    }
    return null;
  }

  function defaultPrefixes(brandId) {
    const b = brandById(brandId);
    if (b) return { coupler: b.prefixes.coupler, io: b.prefixes.io, power: b.prefixes.power };
    return { coupler: 'ADP', io: 'IO', power: 'PWR' };
  }

  function cloneCatalog(list) {
    return (list || []).map(function (item) {
      return {
        brand: String(item.brand || ''),
        pn: String(item.pn || ''),
        description: String(item.description || ''),
        channels: Number(item.channels) || 0,
        signalType: String(item.signalType || ''),
        rawMin: item.rawMin === undefined || item.rawMin === null ? '' : String(item.rawMin),
        rawMax: item.rawMax === undefined || item.rawMax === null ? '' : String(item.rawMax),
        widthMm: item.widthMm === undefined || item.widthMm === null ? '' : String(item.widthMm),
        ebusMa: item.ebusMa === undefined || item.ebusMa === null ? '' : String(item.ebusMa),
        bits: item.bits === undefined || item.bits === null ? '' : String(item.bits),
      };
    });
  }

  function defaultGenericCounts() {
    const counts = { coupler: 1, power: 0 };
    for (let i = 0; i < GENERIC_TYPES.length; i++) {
      const t = GENERIC_TYPES[i];
      counts[t.key] = { points: 0, density: t.density };
    }
    return counts;
  }

  function cloneGenericCounts(src) {
    const base = defaultGenericCounts();
    if (!src || typeof src !== 'object') return base;
    base.coupler = Math.max(0, Math.floor(Number(src.coupler) || 0));
    base.power = Math.max(0, Math.floor(Number(src.power) || 0));
    for (let i = 0; i < GENERIC_TYPES.length; i++) {
      const key = GENERIC_TYPES[i].key;
      const row = src[key];
      if (row && typeof row === 'object') {
        base[key] = {
          points: Math.max(0, Math.floor(Number(row.points) || 0)),
          density: Math.max(1, Math.floor(Number(row.density) || GENERIC_TYPES[i].density)),
        };
      } else if (typeof src[key] === 'number') {
        base[key] = { points: Math.max(0, Math.floor(src[key])), density: GENERIC_TYPES[i].density };
      }
    }
    return base;
  }

  function emptyStation(n) {
    const brand = 'beckhoff-ethercat';
    const p = defaultPrefixes(brand);
    return {
      id: 'st-' + n,
      controller: 'PLC-1',
      stationName: n === 1 ? 'Station 1' : 'Station ' + n,
      brand: brand,
      mode: 'catalog',
      allowMixed: false,
      couplerPrefix: p.coupler,
      ioPrefix: p.io,
      powerPrefix: p.power,
      modules: [],
      genericCounts: defaultGenericCounts(),
    };
  }

  function isGenericStation(station) {
    const st = station || {};
    return st.mode === 'generic' || st.brand === 'generic';
  }

  function catalogByPn(list, pn) {
    const key = String(pn || '').trim().toUpperCase();
    const rows = Array.isArray(list) ? list : [];
    for (let i = 0; i < rows.length; i++) {
      if (String(rows[i].pn || '').trim().toUpperCase() === key) return rows[i];
    }
    return null;
  }

  function signalFamily(signalType) {
    const s = String(signalType || '').trim();
    const u = s.toUpperCase();
    if (u === 'IO-LINK' || u.indexOf('IO-LINK') === 0 || u === 'IOLINK' || u.indexOf('IOLINK') === 0) return 'IO-Link';
    if (u === 'RTD' || u.indexOf('RTD') === 0) return 'RTD';
    if (u === 'TC' || u.indexOf('TC ') === 0 || u.indexOf('TC(') === 0 || u.indexOf('THERMO') === 0) return 'TC';
    if (u === 'DI' || u.indexOf('DI ') === 0 || u.indexOf('DI(') === 0 || u.indexOf('DI (') === 0) return 'DI';
    if (u === 'DO' || u.indexOf('DO ') === 0 || u.indexOf('DO(') === 0 || u.indexOf('DO (') === 0) return 'DO';
    if (u === 'AI' || u.indexOf('AI ') === 0 || u.indexOf('AI(') === 0 || u.indexOf('AI (') === 0) return 'AI';
    if (u === 'AO' || u.indexOf('AO ') === 0 || u.indexOf('AO(') === 0 || u.indexOf('AO (') === 0) return 'AO';
    if (u === 'POWER' || u.indexOf('POWER') === 0 || u === '24VDC') return 'power';
    if (u === 'COUPLER' || u === 'ETHERCAT' || u === 'ADAPTER' || u === 'INTERFACE' || u === 'CHASSIS' || u === 'CPU' || u.indexOf('COUPLER') === 0) return 'coupler';
    return 'other';
  }

  function colorKey(signalType) {
    const f = signalFamily(signalType);
    if (f === 'AI' && /0\s*[-–\/]\s*10/.test(String(signalType || ''))) return 'AI-V';
    return f;
  }

  function typeColor(signalType) {
    const key = colorKey(signalType);
    return TYPE_COLORS[key] || TYPE_COLORS.other;
  }

  function isAnalogFamily(signalType) {
    const f = signalFamily(signalType);
    return f === 'AI' || f === 'AO' || f === 'RTD' || f === 'TC';
  }

  function isChannelFamily(signalType) {
    const f = signalFamily(signalType);
    return f === 'DI' || f === 'DO' || f === 'AI' || f === 'AO' || f === 'RTD' || f === 'TC' || f === 'IO-Link';
  }

  function cardKind(signalType) {
    const f = signalFamily(signalType);
    if (f === 'power') return 'power';
    if (f === 'coupler') return 'coupler';
    return 'io';
  }

  function paddedCardName(prefix, seq) {
    const n = 100 + Math.max(1, Math.floor(Number(seq) || 1));
    return String(prefix || '') + String(n).padStart(4, '0');
  }

  function stationPrefixes(station) {
    const d = defaultPrefixes(station && station.brand);
    const st = station || {};
    return {
      coupler: st.couplerPrefix !== undefined && st.couplerPrefix !== null && String(st.couplerPrefix) !== '' ? String(st.couplerPrefix) : (st.cardPrefix || d.coupler),
      io: st.ioPrefix !== undefined && st.ioPrefix !== null && String(st.ioPrefix) !== '' ? String(st.ioPrefix) : (st.cardPrefix || d.io),
      power: st.powerPrefix !== undefined && st.powerPrefix !== null && String(st.powerPrefix) !== '' ? String(st.powerPrefix) : (st.cardPrefix || d.power),
    };
  }

  function prefixesMatchDefaults(station, brandId) {
    const d = defaultPrefixes(brandId);
    const p = stationPrefixes(station);
    return p.coupler === d.coupler && p.io === d.io && p.power === d.power;
  }

  function genericCountsToModules(counts) {
    const c = cloneGenericCounts(counts);
    const out = [];
    let i;
    for (i = 0; i < c.coupler; i++) {
      out.push({
        pn: 'Generic Coupler',
        description: 'Generic coupler / adapter / CPU slot',
        channels: 0,
        signalType: 'Coupler',
        rawMin: '',
        rawMax: '',
        widthMm: '',
        ebusMa: '',
        bits: '',
        brand: 'generic',
        qty: 1,
      });
    }
    for (i = 0; i < GENERIC_TYPES.length; i++) {
      const t = GENERIC_TYPES[i];
      const row = c[t.key] || { points: 0, density: t.density };
      const points = Math.max(0, Math.floor(Number(row.points) || 0));
      const density = Math.max(1, Math.floor(Number(row.density) || t.density));
      let left = points;
      while (left > 0) {
        out.push({
          pn: t.label,
          description: t.label + ' · ' + density + ' ch/card',
          channels: density,
          signalType: t.signalType,
          rawMin: t.rawMin || '',
          rawMax: t.rawMax || '',
          widthMm: '',
          ebusMa: '',
          bits: t.bits || '',
          brand: 'generic',
          qty: 1,
        });
        left -= density;
      }
    }
    for (i = 0; i < c.power; i++) {
      out.push({
        pn: 'Generic Power',
        description: 'Generic power / bus-refresh slot',
        channels: 0,
        signalType: 'Power',
        rawMin: '',
        rawMax: '',
        widthMm: '',
        ebusMa: '',
        bits: '',
        brand: 'generic',
        qty: 1,
      });
    }
    return out;
  }

  function resolveEntry(item, catalogList) {
    const fromCat = catalogByPn(catalogList, item && item.pn);
    if (fromCat) return fromCat;
    const it = item || {};
    return {
      brand: String(it.brand || ''),
      pn: String(it.pn || ''),
      description: String(it.description || ''),
      channels: Number(it.channels) || 0,
      signalType: String(it.signalType || ''),
      rawMin: it.rawMin === undefined || it.rawMin === null ? '' : String(it.rawMin),
      rawMax: it.rawMax === undefined || it.rawMax === null ? '' : String(it.rawMax),
      widthMm: it.widthMm === undefined || it.widthMm === null ? '' : String(it.widthMm),
      ebusMa: it.ebusMa === undefined || it.ebusMa === null ? '' : String(it.ebusMa),
      bits: it.bits === undefined || it.bits === null ? '' : String(it.bits),
    };
  }

  function stationModuleList(station) {
    if (isGenericStation(station)) return genericCountsToModules(station.genericCounts);
    return Array.isArray(station && station.modules) ? station.modules : [];
  }

  function blankRow() {
    const row = {};
    for (let i = 0; i < COLUMNS.length; i++) row[COLUMNS[i]] = '';
    return row;
  }

  function makeChannelRow(opts) {
    const row = blankRow();
    const family = signalFamily(opts.signalType);
    row.Controller = opts.controller;
    row['Card Name'] = opts.cardName;
    row['Card Part Number'] = opts.partNumber;
    row['Station Name'] = opts.stationName;
    row['Slot Number'] = String(opts.slot);
    row['Channel Number'] = opts.channel === '' || opts.channel === undefined || opts.channel === null ? '' : String(opts.channel);
    row['Wire Terminal'] = row['Channel Number'];
    row['Signal Type'] = opts.signalType;
    if (family === 'DO') {
      row.Min = '0';
      row.Max = '1';
      row.Units = 'BOOL';
      row['Raw Min'] = '0';
      row['Raw Max'] = '1';
    } else if (isAnalogFamily(opts.signalType)) {
      row['Raw Min'] = opts.rawMin === undefined || opts.rawMin === null ? '' : String(opts.rawMin);
      row['Raw Max'] = opts.rawMax === undefined || opts.rawMax === null ? '' : String(opts.rawMax);
    }
    return row;
  }

  /**
   * Expand a station/module BUILD LIST (or generic counts) into one row per
   * channel. Zero-channel modules still emit one documentation row and still
   * consume a slot. Card names use independent coupler / I/O / power sequences
   * padded as prefix + (100+seq) → KEC0101.
   */
  function expandBuildList(stationList, catalogList) {
    const rows = [];
    const stationsIn = Array.isArray(stationList) ? stationList : [];
    const cat = Array.isArray(catalogList) ? catalogList : [];
    for (let s = 0; s < stationsIn.length; s++) {
      const station = stationsIn[s] || {};
      const controller = String(station.controller || '');
      const stationName = String(station.stationName || '');
      const pfx = stationPrefixes(station);
      const modules = stationModuleList(station, cat);
      let slot = 0;
      let couplerSeq = 0;
      let ioSeq = 0;
      let powerSeq = 0;
      for (let m = 0; m < modules.length; m++) {
        const item = modules[m] || {};
        const qty = Math.max(1, Math.floor(Number(item.qty) || 1));
        const entry = resolveEntry(item, cat);
        const partNumber = entry.pn || String(item.pn || '');
        const signalType = entry.signalType || String(item.signalType || '');
        const channels = Number(entry.channels) || 0;
        const rawMin = entry.rawMin;
        const rawMax = entry.rawMax;
        const kind = cardKind(signalType);
        for (let q = 0; q < qty; q++) {
          slot += 1;
          let cardName;
          if (kind === 'coupler') {
            couplerSeq += 1;
            cardName = paddedCardName(pfx.coupler, couplerSeq);
          } else if (kind === 'power') {
            powerSeq += 1;
            cardName = paddedCardName(pfx.power, powerSeq);
          } else {
            ioSeq += 1;
            cardName = paddedCardName(pfx.io, ioSeq);
          }
          if (channels <= 0) {
            rows.push(makeChannelRow({
              controller: controller,
              cardName: cardName,
              partNumber: partNumber,
              stationName: stationName,
              slot: slot,
              channel: '',
              signalType: signalType,
              rawMin: rawMin,
              rawMax: rawMax,
            }));
          } else {
            for (let ch = 1; ch <= channels; ch++) {
              rows.push(makeChannelRow({
                controller: controller,
                cardName: cardName,
                partNumber: partNumber,
                stationName: stationName,
                slot: slot,
                channel: ch,
                signalType: signalType,
                rawMin: rawMin,
                rawMax: rawMax,
              }));
            }
          }
        }
      }
    }
    return rows;
  }

  function parseMa(value) {
    if (value === undefined || value === null || String(value).trim() === '') return null;
    const n = Number(value);
    return isFinite(n) ? n : null;
  }

  /**
   * E-bus / rack current rows from the BUILD LIST (not the edited grid).
   * Signed contribution: coupler/adapter supply is positive, terminals draw
   * negative. Power family resets remaining to that module's contribution.
   */
  function ebusRowsFromBuild(stationList, catalogList, reserveMa) {
    const stationsIn = Array.isArray(stationList) ? stationList : [];
    const cat = Array.isArray(catalogList) ? catalogList : [];
    const reserve = isFinite(Number(reserveMa)) ? Number(reserveMa) : 200;
    const rows = [];
    for (let s = 0; s < stationsIn.length; s++) {
      const station = stationsIn[s] || {};
      const location = String(station.stationName || '');
      const pfx = stationPrefixes(station);
      const modules = stationModuleList(station, cat);
      let slot = 0;
      let couplerSeq = 0;
      let ioSeq = 0;
      let powerSeq = 0;
      let remaining = 0;
      for (let m = 0; m < modules.length; m++) {
        const item = modules[m] || {};
        const qty = Math.max(1, Math.floor(Number(item.qty) || 1));
        const entry = resolveEntry(item, cat);
        const kind = cardKind(entry.signalType);
        for (let q = 0; q < qty; q++) {
          slot += 1;
          let cardName;
          if (kind === 'coupler') {
            couplerSeq += 1;
            cardName = paddedCardName(pfx.coupler, couplerSeq);
          } else if (kind === 'power') {
            powerSeq += 1;
            cardName = paddedCardName(pfx.power, powerSeq);
          } else {
            ioSeq += 1;
            cardName = paddedCardName(pfx.io, ioSeq);
          }
          const contrib = parseMa(entry.ebusMa);
          const reset = kind === 'power';
          if (contrib === null) {
            /* unknown — treat as 0, remaining unchanged (or reset to 0) */
            if (reset) remaining = 0;
          } else if (reset) {
            remaining = contrib;
          } else {
            remaining += contrib;
          }
          const flag = remaining < 0 ? 'NEGATIVE' : (remaining < reserve ? 'LOW RESERVE' : '');
          rows.push({
            Location: location,
            Slot: String(slot),
            'Card Name': cardName,
            'Part Type': entry.pn,
            Description: entry.description,
            'Width mm': entry.widthMm,
            'Current contribution mA': contrib === null ? '' : String(contrib),
            'Running total mA': contrib === null && !reset ? String(remaining) : String(remaining),
            Flag: flag,
            'Signal Type': entry.signalType,
          });
        }
      }
    }
    return rows;
  }

  function scalingRowsFromIo(ioRows, catalogList) {
    const list = Array.isArray(ioRows) ? ioRows : [];
    const cat = Array.isArray(catalogList) ? catalogList : [];
    const out = [];
    for (let i = 0; i < list.length; i++) {
      const row = list[i] || {};
      if (!isAnalogFamily(row['Signal Type'])) continue;
      if (!row['Channel Number']) continue;
      const entry = catalogByPn(cat, row['Card Part Number']);
      let bits = entry && entry.bits ? String(entry.bits) : '';
      if (!bits) {
        const rawMax = Number(row['Raw Max']);
        if (rawMax === 4095) bits = '12';
        else if (rawMax === 27648) bits = '15';
        else if (rawMax === 65535) bits = '16';
        else if (rawMax === 32767 || rawMax === 8000) bits = '16';
      }
      out.push({
        Variable: '',
        'Fuzzy Matched IO Variable': '',
        'Raw Min': row['Raw Min'] || '',
        'Eng Min': '',
        'Raw Max': row['Raw Max'] || '',
        'Eng Max': '',
        'Inferred Unit': '',
        'Inferred Bit Resolution': bits,
      });
    }
    return out;
  }

  function summarizeRows(rows) {
    const totals = {
      DI: 0, DO: 0, AI: 0, AO: 0, RTD: 0, TC: 0, 'IO-Link': 0,
      analogInputs: 0,
      couplers: 0,
      power: 0,
      spare: 0,
      totalChannels: 0,
      rows: 0,
      slots: 0,
    };
    const slots = new Set();
    const list = Array.isArray(rows) ? rows : [];
    totals.rows = list.length;
    for (let i = 0; i < list.length; i++) {
      const row = list[i] || {};
      const family = signalFamily(row['Signal Type']);
      const slotKey = [row.Controller, row['Station Name'], row['Slot Number']].join('\u0001');
      slots.add(slotKey);
      if (family === 'coupler') totals.couplers += 1;
      if (family === 'power') totals.power += 1;
      if (isChannelFamily(row['Signal Type'])) {
        totals.totalChannels += 1;
        if (Object.prototype.hasOwnProperty.call(totals, family)) totals[family] += 1;
        if (family === 'AI' || family === 'RTD' || family === 'TC') totals.analogInputs += 1;
        const desc = String(row.Description || '').trim();
        const tag = String(row['Linked PLC Variable Name'] || '').trim();
        if (desc === '' && tag === '') totals.spare += 1;
      }
    }
    totals.slots = slots.size;
    return totals;
  }

  function rowsToAoa(rows, columns) {
    const cols = columns || COLUMNS;
    const aoa = [cols.slice()];
    const list = Array.isArray(rows) ? rows : [];
    for (let i = 0; i < list.length; i++) {
      const row = list[i] || {};
      const line = [];
      for (let c = 0; c < cols.length; c++) {
        const val = row[cols[c]];
        line.push(val === undefined || val === null ? '' : String(val));
      }
      aoa.push(line);
    }
    return aoa;
  }

  function csvEscape(value) {
    const s = value === undefined || value === null ? '' : String(value);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function rowsToCsv(rows, columns) {
    const aoa = rowsToAoa(rows, columns);
    return aoa.map(function (line) {
      return line.map(csvEscape).join(',');
    }).join('\r\n') + '\r\n';
  }

  function summarySheetAoa(summary) {
    return [
      ['Metric', 'Value'],
      ['Analog Inputs (AI)', summary.analogInputs],
      ['Analog Outputs (AO)', summary.AO],
      ['Digital Inputs (DI)', summary.DI],
      ['Digital Outputs (DO)', summary.DO],
      ['Couplers', summary.couplers],
      ['Power Modules', summary.power],
      ['Spare Channels', summary.spare],
      ['Total Channels', summary.totalChannels],
    ];
  }

  function serializeProject(stationList, catalogList) {
    return {
      version: 2,
      kind: 'io-list-build',
      catalog: cloneCatalog(catalogList || catalog),
      stations: (stationList || stations).map(function (st) {
        return {
          id: st.id,
          controller: st.controller,
          stationName: st.stationName,
          brand: st.brand,
          mode: isGenericStation(st) ? 'generic' : 'catalog',
          allowMixed: !!st.allowMixed,
          couplerPrefix: st.couplerPrefix,
          ioPrefix: st.ioPrefix,
          powerPrefix: st.powerPrefix,
          genericCounts: cloneGenericCounts(st.genericCounts),
          modules: (st.modules || []).map(function (m) {
            return { pn: m.pn, qty: m.qty };
          }),
        };
      }),
    };
  }

  function parseProject(raw) {
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!data || typeof data !== 'object') throw new Error('Not a JSON object.');
    if (data.kind && data.kind !== 'io-list-build') {
      throw new Error('This file is not an I/O list build (kind=' + data.kind + ').');
    }
    const nextCatalog = Array.isArray(data.catalog) && data.catalog.length
      ? cloneCatalog(data.catalog)
      : cloneCatalog(SEED_CATALOG);
    const nextStations = Array.isArray(data.stations) && data.stations.length
      ? data.stations.map(function (st, i) {
        const brand = String(st.brand || (st.mode === 'generic' ? 'generic' : 'beckhoff-ethercat'));
        const mode = st.mode === 'generic' || brand === 'generic' ? 'generic' : 'catalog';
        const d = defaultPrefixes(brand);
        const cardPrefix = st.cardPrefix !== undefined && st.cardPrefix !== null ? String(st.cardPrefix) : '';
        return {
          id: st.id || ('st-' + (i + 1)),
          controller: String(st.controller || ''),
          stationName: String(st.stationName || ''),
          brand: brand,
          mode: mode,
          allowMixed: !!st.allowMixed,
          couplerPrefix: st.couplerPrefix !== undefined && st.couplerPrefix !== null ? String(st.couplerPrefix) : (cardPrefix || d.coupler),
          ioPrefix: st.ioPrefix !== undefined && st.ioPrefix !== null ? String(st.ioPrefix) : (cardPrefix || d.io),
          powerPrefix: st.powerPrefix !== undefined && st.powerPrefix !== null ? String(st.powerPrefix) : (cardPrefix || d.power),
          genericCounts: cloneGenericCounts(st.genericCounts),
          modules: Array.isArray(st.modules) ? st.modules.map(function (m) {
            return { pn: String(m.pn || ''), qty: Math.max(1, Math.floor(Number(m.qty) || 1)) };
          }) : [],
        };
      })
      : [emptyStation(1)];
    return { catalog: nextCatalog, stations: nextStations };
  }

  function xlsxCellStyle(fill, font) {
    return {
      fill: { patternType: 'solid', fgColor: { rgb: fill } },
      font: { color: { rgb: font }, sz: 10, name: 'Calibri' },
      alignment: { vertical: 'center' },
      border: {
        top: { style: 'thin', color: { rgb: 'CBD5E0' } },
        bottom: { style: 'thin', color: { rgb: 'CBD5E0' } },
        left: { style: 'thin', color: { rgb: 'CBD5E0' } },
        right: { style: 'thin', color: { rgb: 'CBD5E0' } },
      },
    };
  }

  function applySheetColors(sheet, aoa, rowSignalTypes, headerFill) {
    if (!sheet) return;
    const header = xlsxCellStyle(headerFill || HEADER_STYLE.fill, HEADER_STYLE.font);
    header.font.bold = true;
    const cols = aoa[0] ? aoa[0].length : 0;
    function encodeCell(r, c) {
      let s = '';
      let cc = c;
      do {
        s = String.fromCharCode((cc % 26) + 65) + s;
        cc = Math.floor(cc / 26) - 1;
      } while (cc >= 0);
      return s + String(r + 1);
    }
    for (let c = 0; c < cols; c++) {
      const cell = sheet[encodeCell(0, c)];
      if (cell) cell.s = header;
    }
    for (let r = 1; r < aoa.length; r++) {
      const sig = rowSignalTypes ? rowSignalTypes[r - 1] : '';
      const pal = typeColor(sig);
      const style = xlsxCellStyle(pal.fill, pal.font);
      for (let c = 0; c < cols; c++) {
        const cell = sheet[encodeCell(r, c)];
        if (cell) cell.s = style;
      }
    }
  }

  function loadXlsx() {
    if (xlsxPromise) return xlsxPromise;
    xlsxPromise = new Promise(function (resolve, reject) {
      if (global.XLSX && global.XLSX.utils) return resolve(global.XLSX);
      const s = document.createElement('script');
      s.src = XLSX_SRC;
      s.onload = function () {
        if (global.XLSX && global.XLSX.utils) resolve(global.XLSX);
        else reject(new Error('SheetJS loaded but did not register'));
      };
      s.onerror = function () {
        xlsxPromise = null;
        reject(new Error('Could not load the local SheetJS library'));
      };
      document.head.appendChild(s);
    });
    return xlsxPromise;
  }

  function downloadBlob(filename, blob) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  function downloadText(filename, text, mime) {
    downloadBlob(filename, new Blob([text], { type: mime || 'text/plain' }));
  }

  function el(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function brandOptionsHtml(selected) {
    return BRANDS.map(function (b) {
      return '<option value="' + escapeHtml(b.id) + '"' + (b.id === selected ? ' selected' : '') + '>' + escapeHtml(b.label) + '</option>';
    }).join('');
  }

  function catalogForStation(st) {
    if (!st) return catalog;
    if (st.allowMixed || isGenericStation(st)) return catalog;
    return catalog.filter(function (c) {
      return !c.brand || c.brand === st.brand || c.brand === 'generic';
    });
  }

  function setStatus(msg) {
    const host = el('iol_status');
    if (host) host.textContent = msg || '';
  }

  function renderCatalog() {
    const host = el('iol_catalog_host');
    if (!host) return;
    const filterSel = el('iol_catalog_brand_filter');
    if (filterSel && catalogBrandFilter !== filterSel.value) {
      /* keep in sync if we re-rendered the select */
    }
    let html = '<div class="ref-table-wrap iol-table-wrap"><table class="ref-table iol-table" aria-label="I/O module catalog">';
    html += '<thead><tr><th scope="col">Brand</th><th scope="col">Part number</th><th scope="col">Description</th><th scope="col">Ch</th><th scope="col">Signal type</th><th scope="col">Raw min</th><th scope="col">Raw max</th><th scope="col">Width mm</th><th scope="col">E-bus mA</th><th scope="col">Bits</th><th scope="col"> </th></tr></thead><tbody>';
    for (let i = 0; i < catalog.length; i++) {
      const c = catalog[i];
      if (catalogBrandFilter && c.brand !== catalogBrandFilter) continue;
      const analog = isAnalogFamily(c.signalType);
      html += '<tr class="' + escapeHtml(typeColor(c.signalType).html) + '" data-index="' + i + '">';
      html += '<td><select data-iol-cat="brand" data-i="' + i + '" aria-label="Catalog brand">' + brandOptionsHtml(c.brand) + '</select></td>';
      html += '<td><input type="text" data-iol-cat="pn" data-i="' + i + '" value="' + escapeHtml(c.pn) + '" aria-label="Part number"></td>';
      html += '<td><input type="text" data-iol-cat="description" data-i="' + i + '" value="' + escapeHtml(c.description) + '" aria-label="Description"></td>';
      html += '<td><input type="number" min="0" step="1" data-iol-cat="channels" data-i="' + i + '" value="' + escapeHtml(c.channels) + '" aria-label="Channel count"></td>';
      html += '<td><input type="text" list="iol_signal_types" data-iol-cat="signalType" data-i="' + i + '" value="' + escapeHtml(c.signalType) + '" aria-label="Signal type"></td>';
      html += '<td><input type="text" data-iol-cat="rawMin" data-i="' + i + '" value="' + escapeHtml(c.rawMin) + '" aria-label="Raw min"' + (analog ? '' : ' placeholder="analog"') + '></td>';
      html += '<td><input type="text" data-iol-cat="rawMax" data-i="' + i + '" value="' + escapeHtml(c.rawMax) + '" aria-label="Raw max"' + (analog ? '' : ' placeholder="analog"') + '></td>';
      html += '<td><input type="text" data-iol-cat="widthMm" data-i="' + i + '" value="' + escapeHtml(c.widthMm) + '" aria-label="Width mm"></td>';
      html += '<td><input type="text" data-iol-cat="ebusMa" data-i="' + i + '" value="' + escapeHtml(c.ebusMa) + '" aria-label="E-bus mA signed" placeholder="signed"></td>';
      html += '<td><input type="text" data-iol-cat="bits" data-i="' + i + '" value="' + escapeHtml(c.bits) + '" aria-label="Bit resolution"></td>';
      html += '<td><button type="button" class="btn-remove" data-iol-cat-remove="' + i + '" aria-label="Remove catalog part ' + escapeHtml(c.pn) + '">×</button></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function renderGenericForm(st, s) {
    const c = cloneGenericCounts(st.genericCounts);
    let html = '<div class="iol-generic">';
    html += '<p class="note">Counts are channel points packed into cards at the density you set. Extra channels on the last card stay spare (blank Description). Coupler and Power occupy a slot with no channel numbers.</p>';
    html += '<div class="input-group">';
    html += '<div><label for="iol_g_cpl_' + s + '">Coupler / adapter slots</label><input type="number" min="0" step="1" id="iol_g_cpl_' + s + '" data-iol-gen="coupler" data-s="' + s + '" value="' + c.coupler + '"></div>';
    html += '<div><label for="iol_g_pwr_' + s + '">Power / refresh slots</label><input type="number" min="0" step="1" id="iol_g_pwr_' + s + '" data-iol-gen="power" data-s="' + s + '" value="' + c.power + '"></div>';
    html += '</div>';
    html += '<div class="ref-table-wrap iol-table-wrap"><table class="ref-table iol-table" aria-label="Generic channel counts">';
    html += '<thead><tr><th scope="col">Type</th><th scope="col">Channel points</th><th scope="col">Channels per card</th></tr></thead><tbody>';
    for (let i = 0; i < GENERIC_TYPES.length; i++) {
      const t = GENERIC_TYPES[i];
      const row = c[t.key];
      html += '<tr class="' + escapeHtml(typeColor(t.signalType).html) + '">';
      html += '<th scope="row">' + escapeHtml(t.signalType) + '</th>';
      html += '<td><input type="number" min="0" step="1" data-iol-gen="' + t.key + '.points" data-s="' + s + '" value="' + row.points + '" aria-label="' + escapeHtml(t.key) + ' points"></td>';
      html += '<td><input type="number" min="1" step="1" data-iol-gen="' + t.key + '.density" data-s="' + s + '" value="' + row.density + '" aria-label="' + escapeHtml(t.key) + ' density"></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div></div>';
    return html;
  }

  function renderStations() {
    const host = el('iol_stations_host');
    if (!host) return;
    let html = '';
    for (let s = 0; s < stations.length; s++) {
      const st = stations[s];
      const generic = isGenericStation(st);
      const pickerCat = catalogForStation(st);
      const options = pickerCat.map(function (c) {
        return '<option value="' + escapeHtml(c.pn) + '">' + escapeHtml(c.pn + ' — ' + c.description + ' (' + c.signalType + ', ' + c.channels + ' ch)') + '</option>';
      }).join('');
      html += '<div class="iol-station" data-station="' + escapeHtml(st.id) + '">';
      html += '<div class="iol-station-head">';
      html += '<strong>' + escapeHtml(st.stationName || ('Station ' + (s + 1))) + '</strong>';
      html += '<button type="button" class="btn btn-secondary btn-sm" data-iol-remove-station="' + s + '">Remove station</button>';
      html += '</div>';
      html += '<div class="input-group">';
      html += '<div><label for="iol_brand_' + s + '">PLC brand / platform</label><select id="iol_brand_' + s + '" data-iol-st="brand" data-s="' + s + '">' + brandOptionsHtml(st.brand) + '</select></div>';
      html += '<div><label for="iol_ctrl_' + s + '">Controller</label><input type="text" id="iol_ctrl_' + s + '" data-iol-st="controller" data-s="' + s + '" value="' + escapeHtml(st.controller) + '"></div>';
      html += '<div><label for="iol_name_' + s + '">Station name</label><input type="text" id="iol_name_' + s + '" data-iol-st="stationName" data-s="' + s + '" value="' + escapeHtml(st.stationName) + '"></div>';
      html += '</div>';
      html += '<div class="input-group triple">';
      html += '<div><label for="iol_cpl_' + s + '">Coupler prefix</label><input type="text" id="iol_cpl_' + s + '" data-iol-st="couplerPrefix" data-s="' + s + '" value="' + escapeHtml(st.couplerPrefix) + '"></div>';
      html += '<div><label for="iol_io_' + s + '">I/O prefix</label><input type="text" id="iol_io_' + s + '" data-iol-st="ioPrefix" data-s="' + s + '" value="' + escapeHtml(st.ioPrefix) + '"></div>';
      html += '<div><label for="iol_pwr_' + s + '">Power prefix</label><input type="text" id="iol_pwr_' + s + '" data-iol-st="powerPrefix" data-s="' + s + '" value="' + escapeHtml(st.powerPrefix) + '"></div>';
      html += '</div>';
      if (!generic) {
        html += '<label class="iol-check"><input type="checkbox" data-iol-st="allowMixed" data-s="' + s + '"' + (st.allowMixed ? ' checked' : '') + '> Allow mixed brands on this station</label>';
      }
      if (generic) {
        html += renderGenericForm(st, s);
      } else {
        html += '<div class="input-group triple iol-cart-add">';
        html += '<div><label for="iol_pn_' + s + '">Catalog part</label><select id="iol_pn_' + s + '">' + options + '</select></div>';
        html += '<div><label for="iol_qty_' + s + '">Quantity</label><input type="number" id="iol_qty_' + s + '" min="1" step="1" value="1"></div>';
        html += '<div class="iol-add-wrap"><button type="button" class="btn btn-sm" data-iol-add="' + s + '">Add to cart</button></div>';
        html += '</div>';
        html += '<ol class="iol-cart" aria-label="Module build list">';
        if (!st.modules.length) {
          html += '<li class="iol-cart-empty">No modules yet. Pick a part number for this brand and add it.</li>';
        }
        let slotPreview = 0;
        for (let m = 0; m < st.modules.length; m++) {
          const item = st.modules[m];
          const entry = catalogByPn(catalog, item.pn);
          const qty = item.qty;
          const ch = entry ? entry.channels : 0;
          const kind = entry ? entry.signalType : '';
          const firstSlot = slotPreview + 1;
          slotPreview += qty;
          const lastSlot = slotPreview;
          const slotLabel = firstSlot === lastSlot ? ('slot ' + firstSlot) : ('slots ' + firstSlot + '–' + lastSlot);
          html += '<li class="' + escapeHtml(typeColor(kind).html) + '">';
          html += '<span>' + escapeHtml(item.pn) + ' × ' + qty + ' · ' + escapeHtml(kind) + ' · ' + ch + ' ch · ' + slotLabel + '</span>';
          html += '<button type="button" class="btn-remove" data-iol-remove-mod="' + s + ':' + m + '" aria-label="Remove ' + escapeHtml(item.pn) + '">×</button>';
          html += '</li>';
        }
        html += '</ol>';
      }
      html += '</div>';
    }
    host.innerHTML = html;
  }

  function renderSummary() {
    const host = el('iol_summary');
    if (!host) return;
    const s = summarizeRows(gridRows);
    host.innerHTML =
      '<div class="res-row iol-sig-ai"><span class="res-label">Analog Inputs (AI+RTD+TC)</span><span class="res-val">' + s.analogInputs + '</span></div>' +
      '<div class="res-row iol-sig-ao"><span class="res-label">Analog Outputs (AO)</span><span class="res-val">' + s.AO + '</span></div>' +
      '<div class="res-row iol-sig-di"><span class="res-label">Digital Inputs (DI)</span><span class="res-val">' + s.DI + '</span></div>' +
      '<div class="res-row iol-sig-do"><span class="res-label">Digital Outputs (DO)</span><span class="res-val">' + s.DO + '</span></div>' +
      '<div class="res-row iol-sig-coupler"><span class="res-label">Couplers</span><span class="res-val">' + s.couplers + '</span></div>' +
      '<div class="res-row iol-sig-power"><span class="res-label">Power modules</span><span class="res-val">' + s.power + '</span></div>' +
      '<div class="res-row"><span class="res-label">Spare channels</span><span class="res-val">' + s.spare + '</span></div>' +
      '<div class="res-row"><span class="res-label">Total channels</span><span class="res-val">' + s.totalChannels + '</span></div>';
    host.classList.add('show');
  }

  function renderGrid() {
    const host = el('iol_grid_host');
    if (!host) return;
    if (!gridRows.length) {
      host.innerHTML = '<p class="note">Generate a list from the parts cart or generic counts, or add a blank row.</p>';
      return;
    }
    let html = '<div class="iol-legend" aria-hidden="true">';
    html += '<span class="iol-sig-di">DI</span><span class="iol-sig-do">DO</span><span class="iol-sig-ai">AI</span><span class="iol-sig-ao">AO</span><span class="iol-sig-rtd">RTD</span><span class="iol-sig-tc">TC</span><span class="iol-sig-iolink">IO-Link</span><span class="iol-sig-coupler">Coupler</span><span class="iol-sig-power">Power</span>';
    html += '</div>';
    html += '<div class="ref-table-wrap iol-grid-wrap"><table class="ref-table iol-grid" aria-label="Editable I/O list">';
    html += '<thead><tr>';
    for (let c = 0; c < COLUMNS.length; c++) {
      html += '<th scope="col">' + escapeHtml(COLUMNS[c]) + '</th>';
    }
    html += '<th scope="col"> </th></tr></thead><tbody>';
    for (let r = 0; r < gridRows.length; r++) {
      html += '<tr class="' + escapeHtml(typeColor(gridRows[r]['Signal Type']).html) + '">';
      for (let c = 0; c < COLUMNS.length; c++) {
        const key = COLUMNS[c];
        const val = gridRows[r][key] === undefined || gridRows[r][key] === null ? '' : String(gridRows[r][key]);
        html += '<td><input type="text" data-iol-cell="' + r + ':' + c + '" value="' + escapeHtml(val) + '" aria-label="' + escapeHtml(key + ' row ' + (r + 1)) + '"></td>';
      }
      html += '<td><button type="button" class="btn-remove" data-iol-del-row="' + r + '" aria-label="Remove row ' + (r + 1) + '">×</button></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function readCatalogField(target) {
    const i = Number(target.getAttribute('data-i'));
    const field = target.getAttribute('data-iol-cat');
    if (!catalog[i] || !field) return;
    if (field === 'channels') catalog[i].channels = Math.max(0, Math.floor(Number(target.value) || 0));
    else catalog[i][field] = target.value;
    if (field === 'brand' || field === 'signalType' || field === 'pn') renderStations();
  }

  function generateFromCart() {
    gridRows = expandBuildList(stations, catalog);
    renderGrid();
    renderSummary();
  }

  function addBlankRow() {
    gridRows.push(blankRow());
    renderGrid();
    renderSummary();
  }

  function stampProjectName() {
    const first = stations[0];
    const name = first && (first.stationName || first.controller);
    const slug = String(name || 'io-list').replace(/[^\w.-]+/g, '-').replace(/^-|-$/g, '');
    return slug || 'io-list';
  }

  function exportCsv() {
    if (!gridRows.length) generateFromCart();
    downloadText(stampProjectName() + '-io-list.csv', rowsToCsv(gridRows, COLUMNS), 'text/csv;charset=utf-8');
  }

  function exportXlsx() {
    if (!gridRows.length) generateFromCart();
    const summary = summarizeRows(gridRows);
    const ebusCols = ['Location', 'Slot', 'Card Name', 'Part Type', 'Description', 'Width mm', 'Current contribution mA', 'Running total mA', 'Flag'];
    const scaleCols = ['Variable', 'Fuzzy Matched IO Variable', 'Raw Min', 'Eng Min', 'Raw Max', 'Eng Max', 'Inferred Unit', 'Inferred Bit Resolution'];
    const ebus = ebusRowsFromBuild(stations, catalog, 200);
    const scaling = scalingRowsFromIo(gridRows, catalog);
    loadXlsx().then(function (XLSXlib) {
      const wb = XLSXlib.utils.book_new();
      const ebusAoa = rowsToAoa(ebus, ebusCols);
      const ioAoa = rowsToAoa(gridRows, COLUMNS);
      const scaleAoa = rowsToAoa(scaling, scaleCols);
      const sumAoa = summarySheetAoa(summary);
      const ebusSheet = XLSXlib.utils.aoa_to_sheet(ebusAoa);
      const ioSheet = XLSXlib.utils.aoa_to_sheet(ioAoa);
      const scaleSheet = XLSXlib.utils.aoa_to_sheet(scaleAoa);
      const sumSheet = XLSXlib.utils.aoa_to_sheet(sumAoa);
      applySheetColors(ebusSheet, ebusAoa, ebus.map(function (r) { return r['Signal Type']; }));
      applySheetColors(ioSheet, ioAoa, gridRows.map(function (r) { return r['Signal Type']; }));
      applySheetColors(scaleSheet, scaleAoa, scaling.map(function () { return 'AI'; }));
      const sumTypes = ['AI', 'AO', 'DI', 'DO', 'coupler', 'power', 'other', 'other'];
      applySheetColors(sumSheet, sumAoa, sumTypes);
      XLSXlib.utils.book_append_sheet(wb, ebusSheet, 'Ebus Current');
      XLSXlib.utils.book_append_sheet(wb, ioSheet, 'IO List');
      XLSXlib.utils.book_append_sheet(wb, scaleSheet, 'Scaling');
      XLSXlib.utils.book_append_sheet(wb, sumSheet, 'Summary');
      const out = XLSXlib.write(wb, { bookType: 'xlsx', type: 'array', cellStyles: true });
      downloadBlob(stampProjectName() + '-io-list.xlsx', new Blob([out], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }));
    }).catch(function (err) {
      setStatus(err.message || String(err));
    });
  }

  function saveProject() {
    const json = JSON.stringify(serializeProject(stations, catalog), null, 2);
    downloadText(stampProjectName() + '-io-build.json', json, 'application/json;charset=utf-8');
  }

  function applyProject(parsed) {
    catalog = parsed.catalog;
    stations = parsed.stations;
    stationSeq = stations.length;
    gridRows = [];
    renderCatalog();
    renderStations();
    renderGrid();
    renderSummary();
  }

  function loadProjectFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function () {
      try {
        applyProject(parseProject(String(reader.result || '')));
        setStatus('Loaded build list from ' + file.name + '. Generate to expand the table.');
      } catch (err) {
        setStatus(err.message || String(err));
      }
    };
    reader.readAsText(file);
  }

  function onSectionClick(ev) {
    const t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.getAttribute('data-iol-cat-remove') !== null) {
      const i = Number(t.getAttribute('data-iol-cat-remove'));
      catalog.splice(i, 1);
      renderCatalog();
      renderStations();
      return;
    }
    if (t.getAttribute('data-iol-remove-station') !== null) {
      const s = Number(t.getAttribute('data-iol-remove-station'));
      stations.splice(s, 1);
      if (!stations.length) stations = [emptyStation(1)];
      renderStations();
      return;
    }
    if (t.getAttribute('data-iol-add') !== null) {
      const s = Number(t.getAttribute('data-iol-add'));
      const pnEl = el('iol_pn_' + s);
      const qtyEl = el('iol_qty_' + s);
      const pn = pnEl ? pnEl.value : '';
      const qty = Math.max(1, Math.floor(Number(qtyEl && qtyEl.value) || 1));
      if (pn && stations[s]) {
        const entry = catalogByPn(catalog, pn);
        if (!stations[s].allowMixed && entry && entry.brand && entry.brand !== stations[s].brand && entry.brand !== 'generic') {
          setStatus('This station is ' + (brandById(stations[s].brand) || {}).label + '. Enable “Allow mixed brands” to add ' + pn + '.');
          return;
        }
        stations[s].modules.push({ pn: pn, qty: qty, id: 'mod-' + (moduleSeq++) });
        renderStations();
      }
      return;
    }
    if (t.getAttribute('data-iol-remove-mod') !== null) {
      const parts = t.getAttribute('data-iol-remove-mod').split(':');
      const s = Number(parts[0]);
      const m = Number(parts[1]);
      if (stations[s]) {
        stations[s].modules.splice(m, 1);
        renderStations();
      }
      return;
    }
    if (t.getAttribute('data-iol-del-row') !== null) {
      const r = Number(t.getAttribute('data-iol-del-row'));
      gridRows.splice(r, 1);
      renderGrid();
      renderSummary();
    }
  }

  function onSectionInput(ev) {
    const t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.id === 'iol_catalog_brand_filter') {
      catalogBrandFilter = t.value;
      renderCatalog();
      return;
    }
    if (t.getAttribute('data-iol-cat') !== null) {
      readCatalogField(t);
      return;
    }
    if (t.getAttribute('data-iol-gen') !== null) {
      const s = Number(t.getAttribute('data-s'));
      const field = t.getAttribute('data-iol-gen');
      if (!stations[s]) return;
      stations[s].genericCounts = cloneGenericCounts(stations[s].genericCounts);
      if (field === 'coupler' || field === 'power') {
        stations[s].genericCounts[field] = Math.max(0, Math.floor(Number(t.value) || 0));
      } else {
        const parts = field.split('.');
        const key = parts[0];
        const sub = parts[1];
        if (!stations[s].genericCounts[key]) stations[s].genericCounts[key] = { points: 0, density: 8 };
        const n = Math.floor(Number(t.value) || 0);
        stations[s].genericCounts[key][sub] = sub === 'density' ? Math.max(1, n) : Math.max(0, n);
      }
      return;
    }
    if (t.getAttribute('data-iol-st') !== null) {
      const s = Number(t.getAttribute('data-s'));
      const field = t.getAttribute('data-iol-st');
      if (!stations[s] || !field) return;
      if (field === 'allowMixed') {
        stations[s].allowMixed = !!t.checked;
        renderStations();
        return;
      }
      if (field === 'brand') {
        const oldBrand = stations[s].brand;
        const next = t.value;
        if (prefixesMatchDefaults(stations[s], oldBrand)) {
          const p = defaultPrefixes(next);
          stations[s].couplerPrefix = p.coupler;
          stations[s].ioPrefix = p.io;
          stations[s].powerPrefix = p.power;
        }
        stations[s].brand = next;
        stations[s].mode = next === 'generic' ? 'generic' : 'catalog';
        renderStations();
        return;
      }
      stations[s][field] = t.value;
      return;
    }
    if (t.getAttribute('data-iol-cell') !== null) {
      const parts = t.getAttribute('data-iol-cell').split(':');
      const r = Number(parts[0]);
      const c = Number(parts[1]);
      if (gridRows[r] && COLUMNS[c]) {
        gridRows[r][COLUMNS[c]] = t.value;
        if (COLUMNS[c] === 'Signal Type' || COLUMNS[c] === 'Channel Number' || COLUMNS[c] === 'Description' || COLUMNS[c] === 'Linked PLC Variable Name') {
          renderSummary();
        }
      }
    }
  }

  function init() {
    if (!el('sec-io-list-generator')) return;
    const filterSel = el('iol_catalog_brand_filter');
    if (filterSel) {
      filterSel.innerHTML = '<option value="">All brands</option>' + brandOptionsHtml('');
    }
    renderCatalog();
    renderStations();
    renderSummary();
    renderGrid();

    const section = el('sec-io-list-generator');
    section.addEventListener('click', onSectionClick);
    section.addEventListener('input', onSectionInput);
    section.addEventListener('change', onSectionInput);

    const addCat = el('iol_add_catalog');
    if (addCat) addCat.addEventListener('click', function () {
      const brand = catalogBrandFilter || (stations[0] && stations[0].brand) || 'beckhoff-ethercat';
      catalog.push({
        brand: brand === 'generic' ? 'beckhoff-ethercat' : brand,
        pn: '', description: '', channels: 0, signalType: 'DI',
        rawMin: '', rawMax: '', widthMm: '', ebusMa: '', bits: '',
      });
      renderCatalog();
      renderStations();
    });
    const addSt = el('iol_add_station');
    if (addSt) addSt.addEventListener('click', function () {
      stationSeq += 1;
      const st = emptyStation(stationSeq);
      const prev = stations[stations.length - 1];
      if (prev) {
        st.brand = prev.brand;
        st.mode = prev.mode;
        const p = defaultPrefixes(st.brand);
        st.couplerPrefix = p.coupler;
        st.ioPrefix = p.io;
        st.powerPrefix = p.power;
      }
      stations.push(st);
      renderStations();
    });
    const gen = el('iol_generate');
    if (gen) gen.addEventListener('click', generateFromCart);
    const addRow = el('iol_add_row');
    if (addRow) addRow.addEventListener('click', addBlankRow);
    const csvBtn = el('iol_export_csv');
    if (csvBtn) csvBtn.addEventListener('click', exportCsv);
    const xlsxBtn = el('iol_export_xlsx');
    if (xlsxBtn) xlsxBtn.addEventListener('click', exportXlsx);
    const saveBtn = el('iol_save');
    if (saveBtn) saveBtn.addEventListener('click', saveProject);
    const loadBtn = el('iol_load');
    const fileEl = el('iol_load_file');
    if (loadBtn && fileEl) {
      loadBtn.addEventListener('click', function () { fileEl.click(); });
      fileEl.addEventListener('change', function () {
        const f = fileEl.files && fileEl.files[0];
        loadProjectFile(f);
        fileEl.value = '';
      });
    }

    window.iolGenerateExample = generateFromCart;

    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-io-list-generator', 'io-list-generator', null);
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__ioListGeneratorTestApi = {
    COLUMNS: COLUMNS,
    BLANK_ON_GENERATE: BLANK_ON_GENERATE,
    BRANDS: BRANDS,
    SEED_CATALOG: cloneCatalog(SEED_CATALOG),
    TYPE_COLORS: TYPE_COLORS,
    GENERIC_TYPES: GENERIC_TYPES,
    expandBuildList: expandBuildList,
    summarizeRows: summarizeRows,
    rowsToCsv: rowsToCsv,
    rowsToAoa: rowsToAoa,
    summarySheetAoa: summarySheetAoa,
    serializeProject: serializeProject,
    parseProject: parseProject,
    paddedCardName: paddedCardName,
    catalogByPn: catalogByPn,
    isAnalogFamily: isAnalogFamily,
    signalFamily: signalFamily,
    typeColor: typeColor,
    colorKey: colorKey,
    ebusRowsFromBuild: ebusRowsFromBuild,
    genericCountsToModules: genericCountsToModules,
    defaultGenericCounts: defaultGenericCounts,
    isGenericStation: isGenericStation,
    stationPrefixes: stationPrefixes,
  };
})(typeof window !== 'undefined' ? window : globalThis);
