const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.join(__dirname,'..');
const js=(f)=>fs.readFileSync(path.join(root,'public/toolbox/js',f),'utf8');
const sb={console,Math,Number,String,Object,Array,JSON,Set,Map,isFinite,parseInt,setTimeout,clearTimeout,encodeURIComponent};sb.window=sb;sb.globalThis=sb;
const c=vm.createContext(sb);vm.runInContext(js('electronics-bench-engine.js'),c);vm.runInContext(js('electronics-bench-render.js'),c);
const E=sb.BeckifyBenchEngine,R=sb.BeckifyBenchRender;
const vals=['','0','-1','1e12','1e308','abc','4.7k'];
const bad=[];let runs=0,ok=0,rejected=0;
const weird=(s)=>/NaN|Infinity|undefined|\[object/.test(s);
for(const id of E.circuits()){
  const sp=E.specOf(id);
  for(const un of sp.unknowns.map(x=>x.id)){
    const vis=(sp.visible&&sp.visible[un])||sp.fields.map(f=>f.id);
    const tests=[['defaults',{}]];
    vis.forEach(f=>vals.forEach(v=>tests.push([f+'='+JSON.stringify(v),{[f]:v}])));
    for(const [tag,over] of tests){
      runs++;
      const inputs=Object.assign({},sp.defaults,over);
      let r;try{r=E.solveSafe(id,un,inputs)}catch(e){bad.push(`${id}/${un} ${tag} THROW ${e.message}`);continue}
      if(!r.ok){rejected++;if(!r.error||weird(r.error))bad.push(`${id}/${un} ${tag} bad error ${r.error}`);continue}
      ok++;const s=r.solution;
      const txt=[s.headline,(s.steps||[]).join(' '),(s.notes||[]).join(' '),s.warning||''].concat(s.nodes.map(n=>n.name+E.si(n.value,n.unit==null?'V':n.unit)),s.branches.map(b=>b.name+E.si(b.value,b.unit==null?'A':b.unit))).join(' | ');
      if(weird(txt))bad.push(`${id}/${un} ${tag} WEIRD ${txt.slice(0,140)}`);
      try{
        const a=R.renderSchematic(s,{});if(weird(a.replace(/aria-label="[^"]*"/,'')))bad.push(`${id}/${un} ${tag} schematic weird`);
        if(s.layout){const b=R.renderBreadboard(s.layout,{});if(weird(b.replace(/aria-label="[^"]*"/,'')))bad.push(`${id}/${un} ${tag} bb weird`);
          const au=E.auditBoard(s.layout);if(au&&au.length&&tag==='defaults')bad.push(`${id}/${un} audit ${JSON.stringify(au).slice(0,100)}`);}
      }catch(e){bad.push(`${id}/${un} ${tag} RENDER THROW ${e.message}`)}
    }
  }
}
require('node:assert/strict').equal(bad.length,0,bad.slice(0,10).join('\n'));require('node:assert/strict').equal(E.circuits().length,41);console.log('bench fuzz ok',runs,'runs');
