:- ['../jsonld.pl', 'data.pl'] .

passedAll :- \+ notPassed(_) .

passed(F) :- expected(F, G), actual(F, G) .

notPassed(F) :- expected(F, G), actual(F, Gp), G \= Gp .

actual(F, G) :- findall((S, P, O), rdf(S, P, O, F), Gp), sort(Gp, G) .

% See JSON-LD 1.0, Section 5 "Basic Concepts" %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expected('intro.jsonld',
         [(_, 'http://schema.org/image', 'http://manu.sporny.org/images/manu.png'),
          (_, 'http://schema.org/name', 'Manu Sporny'),
          (_, 'http://schema.org/url', 'http://manu.sporny.org/')]) .

expected('ctx-remote.jsonld', []) . % TODO IRI dereferencing

expected('ctx-inline.jsonld',
         [(_, 'http://schema.org/image', 'http://manu.sporny.org/images/manu.png'),
          (_, 'http://schema.org/name', 'Manu Sporny'),
          (_, 'http://schema.org/url', 'http://manu.sporny.org/')]) .

expected('iris-ignored.jsonld',
         [(_, 'http://schema.org/name', 'Manu Sporny')]) .

expected('node-id.jsonld',
        [('http://me.markus-lanthaler.com/', 'http://schema.org/name', 'Markus Lanthaler')]) .

expected('type.jsonld',
         [('http://example.org/places#BrewEats', a, 'http://schema.org/Restaurant')]) .

expected('type-array.jsonld',
         [('http://example.org/places#BrewEats', a, 'http://schema.org/Brewery'),
          ('http://example.org/places#BrewEats', a, 'http://schema.org/Restaurant')]) .

expected('type-array-ctx.jsonld',
        [('http://example.org/places#BrewEats', a, 'http://schema.org/Brewery'),
         ('http://example.org/places#BrewEats', a, 'http://schema.org/Restaurant')]) .

% See JSON-LD 1.0, Section 6 "Advanced Concepts" %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% TODO all

expected('base-uri.jsonld', []) .

expected('base-uri-ctx.jsonld', []) .

expected('vocab.jsonld', []) .

expected('vocab-null.jsonld', []) .

expected('curie.jsonld', []) .

expected('curie-ctx.jsonld', []) .

expected('type-ctx.jsonld', []) .

expected('type-coercion.jsonld', []) .

expected('type-coercion-ctx.jsonld', []) .

expected('embedding.jsonld', []) .

expected('multi-ctx.jsonld', []) .

expected('scoped-ctx.jsonld', []) .

expected('combined-ctx.jsonld', []) .

% TODO skipped language features (Section 6.9)

% TODO skipped IRI expansion in context (Section 6.10)

expected('multi-values.jsonld', []) .

expected('multi-expanded-values.jsonld', []) .

expected('list.jsonld', []) .

expected('list-ctx.jsonld', []) .

expected('reverse.jsonld', []) .

expected('reverse-ctx.jsonld', []) .

expected('named-graph.jsonld', []) .

expected('default-graph.jsonld', []) .

expected('alias.jsonld',
         [('http://example.com/about#gregg', a, 'http://xmlns.com/foaf/0.1/Person'),
          ('http://example.com/about#gregg', 'http://xmlns.com/foaf/0.1/name', 'Gregg Kellogg')]) .

expected('index.jsonld', []) .

% See JSON-Ld Playground Examples %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expected('person.jsonld',
         [(_, a, 'http://schema.org/Person'),
          (_, 'http://schema.org/jobTitle', 'Professor'),
          (_, 'http://schema.org/name', 'Jane Doe'),
          (_, 'http://schema.org/telephone', '(425) 123-4567'),
          (_, 'http://schema.org/url', 'http://www.janedoe.com')]) .