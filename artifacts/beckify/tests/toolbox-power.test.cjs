/* Regression tests for the toolbox calculation engine (public/toolbox/js).
   Run with: npm test
   The engine files are plain browser scripts, so they are evaluated in a vm
   context with minimal DOM stubs and the pure functions pulled back out. */
const fs=require('fs'), vm=require('vm');
const dir = require('path').join(__dirname, '..', 'public', 'toolbox', 'js') + '/';
const sandbox={document:{addEventListener(){},getElementById(){return null},querySelectorAll(){return[]}},console,Math,Number,Object,Array,String,Set,JSON,isFinite,parseInt,parseFloat};
sandbox.window=sandbox; vm.createContext(sandbox);
for (const f of ['nec-data.js','wire-tools.js','power-tools.js'])
  vm.runInContext(fs.readFileSync(dir+f,'utf8'), sandbox, {filename:f});
const G = vm.runInContext(`({xfmrPrimaryOnlyLimit,xfmrSecondaryLimit,largestStandardAtOrBelow,STD_XFMR_KVA,nextStandardOCPD,pcPhaseMultiplier})`, sandbox);

let fails=0;
const ok=(n,g,w,t)=>{const tol=t===undefined?Math.abs(w)*0.005:t;const p=Math.abs(g-w)<=tol;if(!p)fails++;
  console.log((p?'  PASS  ':'  FAIL  ')+n.padEnd(50)+' got '+(typeof g==='number'?g.toFixed(3):g)+' want ~'+w);};

const S3=Math.sqrt(3);
console.log('\n--- Power conversions (hand calcs) ---');
// 50 kW, 480V 3ph, PF 0.9 -> I = 50000/(1.732*480*0.9) = 66.83 A
ok('3ph 50kW 480V PF.9 -> amps', 50000/(S3*480*0.9), 66.83, 0.02);
// 100 A, 480V 3ph -> kVA = 1.732*480*100/1000 = 83.14
ok('3ph 100A 480V -> kVA', S3*480*100/1000, 83.138, 0.01);
// 1ph 10kW 240V PF 1.0 -> 41.67 A
ok('1ph 10kW 240V PF1 -> amps', 10000/(240*1), 41.667, 0.01);
// 10 HP, 90% eff -> input kW = 10*746/0.9/1000 = 8.289
ok('10HP at 90% eff -> input kW', 10*746/0.9/1000, 8.289, 0.001);
// that at 480V 3ph PF .9 -> I = 8289/(1.732*480*.9) = 11.08 A
ok('10HP 480V 3ph PF.9 -> amps', (10*746/0.9)/(S3*480*0.9), 11.078, 0.01);

console.log('\n--- Transformer standard sizes ---');
ok('90 kVA load -> 100 kVA unit', G.STD_XFMR_KVA.find(k=>k>=90), 100, 0);
ok('112 kVA load -> 112.5 kVA unit', G.STD_XFMR_KVA.find(k=>k>=112), 112.5, 0);
ok('45.1 kVA load -> 50 kVA unit', G.STD_XFMR_KVA.find(k=>k>=45.1), 50, 0);

console.log('\n--- Table 450.3(B) tiers ---');
ok('primary 120A -> 125%', G.xfmrPrimaryOnlyLimit(120).pct, 125, 0);
ok('primary 5A -> 167%', G.xfmrPrimaryOnlyLimit(5).pct, 167, 0);
ok('primary 1.5A -> 300%', G.xfmrPrimaryOnlyLimit(1.5).pct, 300, 0);
ok('primary exactly 9A -> 125%', G.xfmrPrimaryOnlyLimit(9).pct, 125, 0);
ok('primary exactly 2A -> 167%', G.xfmrPrimaryOnlyLimit(2).pct, 167, 0);
ok('secondary 300A -> 125%', G.xfmrSecondaryLimit(300).pct, 125, 0);
ok('secondary 5A -> 167%', G.xfmrSecondaryLimit(5).pct, 167, 0);

console.log('\n--- Worked example: 100 kVA, 480->208 3ph ---');
const kva=100, vp=480, vs=208;
const ip=kva*1000/(S3*vp), is=kva*1000/(S3*vs);
ok('primary FLA', ip, 120.28, 0.05);
ok('secondary FLA', is, 277.57, 0.05);
// Primary only, >=9A -> 125% = 150.35 -> next std up (Note 1) = 175
ok('primary-only ceiling 125%', ip*1.25, 150.35, 0.1);
ok('primary-only device (next std up)', G.nextStandardOCPD(ip*1.25), 175, 0);
// Pri+Sec: primary 250% = 300.7 -> largest std at or below = 300
ok('pri+sec primary ceiling 250%', ip*2.5, 300.71, 0.1);
ok('pri+sec primary device (<= ceiling)', G.largestStandardAtOrBelow(ip*2.5), 300, 0);
// Secondary >=9A -> 125% = 346.96 -> next std up = 350
ok('secondary ceiling 125%', is*1.25, 346.96, 0.1);
ok('secondary device (next std up)', G.nextStandardOCPD(is*1.25), 350, 0);

console.log('\n--- largestStandardAtOrBelow behaviour ---');
ok('exactly on a standard size', G.largestStandardAtOrBelow(200), 200, 0);
ok('just under a standard size', G.largestStandardAtOrBelow(199), 175, 0);
ok('below the smallest', G.largestStandardAtOrBelow(10), null, 0);

console.log(fails?`\n${fails} FAILURE(S)`:'\nAll checks passed'); process.exitCode=fails?1:0;
