const fs = require('fs');

let counter = 0;

function json2pl(val) {
    if (typeof val == 'string') return `'${val}'`;
    else if (typeof val != 'object') return val;
    
    let id = `obj${counter++}`;

    for (let k in val) {
        if (val instanceof Array) k = Number(k);
        console.log(`member(${id}, ${json2pl(k)}, ${json2pl(val[k])}) .`);
    }

    return id;
}

let dir = process.argv[2];

fs.readdirSync(dir)
  .filter(f => f.endsWith('.jsonld'))
  .forEach(f => {
      let json = JSON.parse(fs.readFileSync(dir + '/' + f));
      let root = json2pl(json);
      console.log(`root('${f.substr(f.lastIndexOf('/') + 1)}', ${root}) .`);
  });