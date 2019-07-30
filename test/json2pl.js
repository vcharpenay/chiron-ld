const fs = require('fs');

let counter = 0;

function json2pl(val, facts) {
    if (typeof val == 'string') return `'${val}'`;
    else if (typeof val != 'object') return val;
    
    let id = `obj${counter++}`;

    facts.push(['object', id]);
    if (val instanceof Array) facts.push(['array', id]);

    for (let k in val) {
        if (val instanceof Array) k = Number(k);
        let kId = json2pl(k, facts);
        let valId = json2pl(val[k], facts);
        facts.push(['member', id, kId, valId]);
    }

    return id;
}

let dir = process.argv[2];

let facts = [];

fs.readdirSync(dir)
  .filter(f => f.endsWith('.jsonld'))
  .forEach(f => {
      let json = JSON.parse(fs.readFileSync(dir + '/' + f));
      let root = json2pl(json, facts);
      facts.push(['root', `'${f.substr(f.lastIndexOf('/') + 1)}'`, root]);
  });

facts.sort().forEach(fact => console.log(`${fact[0]}(${fact.slice(1).join(', ')}) .`));