%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% JSON-LD for Prolog
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% JSON predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- dynamic member/3 .
:- dynamic root/2 .
:- dynamic object/1 .
:- dynamic array/1 .

plain(V) :- atom(V), \+ object(V), V \= null .
plain(V) :- number(V) .

% JSON-LD context predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

scheme('http') .
scheme('https') .
scheme('urn') .
scheme('tag') .

% FIXME parse full IRI
absoluteIRI(V) :- atom(V), scheme(S), sub_atom(V, 0, _, _, S) .

curie(V, Prefix, Name) :- \+ absoluteIRI(V),
                          sub_atom(V, N, Len, _, ':'),
                          sub_atom(V, 0, N, _, Prefix),
                          Np is N + Len,
                          sub_atom(V, Np, _, 0, Name) .

keyword('@id') .
keyword('@type') .
keyword('@value') .
keyword('@graph') .
keyword('@language') .
keyword('@list') .
keyword('@set') .
keyword('@context') .
keyword('@container') .
keyword('@reverse') .
keyword('@index') .
keyword('@base') .
keyword('@vocab') .

% FIXME only true if original member is from a node object .
contextDefinition(O) :- member(_, '@context', O), object(O) .
contextDefinition(O) :- member(Op, _, O), object(O), contextDefinition(Op) .

context(C, C) :- contextDefinition(C) .
context(O, C) :- member(O, '@context', C), \+ contextDefinition(O) .
context(O, C) :- member(O, '@context', Cp), array(Cp), member(Cp, _, C), \+ contextDefinition(O) .
context(O, C) :- member(Op, _, O), \+ contextDefinition(O), context(Op, C) .
context(O, C) :- member(Op, K, O), \+ contextDefinition(O),
                 context(Op, Cp), range(Cp, K, C) .
% FIXME finish:
% - infinite loop between context/2 in head and body (refactor overrides/2?)
% - keywordAlias/3 should have a context as input instead of an object (other infinite loop)
%context(O, C) :- range(Cp, T, C), keywordAlias(C, K, '@type'), member(O, K, T),
%                 \+ (range(C, T, _), keywordAlias(C, K, '@type'), member(O, K, T)),
 %                context(O, Cp),
 %                \+ contextDefinition(O) .

% FIXME range relation override contexts, too (and transitive)
overrides(C, Cp) :- contextDefinition(C), contextDefinition(Cp), Cp \= C,
                    context(O, Cp), context(O, C), nodeObject(O),
                    member(Op, _, O), context(Op, Cp) .
%overrides(C, Cs) :- overrides(C, Cp), overrides(Cp, Cs) .

termMapping(C, K, V) :- contextDefinition(C), member(C, K, Vp),
                        ((plain(Vp), V = Vp); member(Vp, '@id', V)) .

range(C, K, Cp) :- contextDefinition(C), member(C, K, V), member(V, '@context', Cp) .

nullMapping(C, K) :- contextDefinition(C), member(C, K, null) .

vocabMapping(C, V) :- contextDefinition(C), member(C, '@vocab', V) .

vocabMapping(C, K, V) :- contextDefinition(C), vocabMapping(C, V), \+ nullMapping(C, K) .

typeMapping(C, K, V) :- contextDefinition(C), member(C, K, O), member(O, '@type', V) .

inverse(C, K, Kp) :- contextDefinition(C), member(C, K, O), member(O, '@reverse', Kp) .

keywordAlias(C, V, Vp) :- termMapping(C, V, Vp), keyword(Vp) .

% JSON-LD main predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

activeContext(O, K, C) :- context(O, C),
                          \+ ((termMapping(C, K, _); vocabMapping(C, K, _)),
                              context(O, Cp),
                              (termMapping(Cp, K, _); vocabMapping(Cp, K, _)),
                              overrides(Cp, C)) .

expandedIRI(_, I, I) :- keyword(I) .
expandedIRI(_, I, I) :- absoluteIRI(I) .
expandedIRI(O, T, I) :- curie(T, Prefix, Name),
                        activeContext(O, Prefix, C), termMapping(C, Prefix, NS),
                        atom_concat(NS, Name, I) .
expandedIRI(O, T, I) :- \+ keyword(T), \+ absoluteIRI(T), \+ curie(T, _, _),
                        activeContext(O, T, C),
                        vocabMapping(C, T, V),
                        atom_concat(V, T, I) .
expandedIRI(O, T, I) :- activeContext(O, T, C), termMapping(C, T, I), absoluteIRI(I) .
expandedIRI(O, T, I) :- activeContext(O, T, C), termMapping(C, T, Tp), expandedIRI(O, Tp, I) .

expandedValue(O, K, T, V) :- plain(T),
                             context(O, C),
                             (typeMapping(C, K, '@id'); typeMapping(C, K, '@vocab')),
                             expandedIRI(O, T, V) .
expandedValue(_, _, T, T) :- plain(T) . % TODO datatype, lang

graph(G, O) :- root(G, O), object(O) . % TODO named graphs
graph(G, Op) :- object(Op), member(O, _, Op), graph(G, O) .

valueObject(O) :- member(O, '@value', _) .

listObject(O) :- member(O, '@list', _) .

setObject(O) :- member(O, '@set', _) .

reverseMap(O) :- member(_, '@reverse', O) .

indexMap(O) :- member(Os, '@container', '@index'),
               member(C, K, Os),
               member(Op, K, O), activeContext(Op, K, C) .

mapObject(O) :- array(O) .
mapObject(O) :- indexMap(O) .

% note: alternative definition:
%  => range of a graph object or a parent node object
nodeObject(O) :- object(O),
                 \+ (valueObject(O);
                     listObject(O);
                     setObject(O);
                     reverseMap(O);
                     mapObject(O);
                     contextDefinition(O)) .

keywordOrAlias(_, V, V) :- keyword(V) .
keywordOrAlias(O, V, Vp) :- activeContext(O, V, C), keywordAlias(C, V, Vp) .

id(O, I) :- nodeObject(O),
            keywordOrAlias(O, K, '@id'), member(O, K, I) .
id(O, I) :- nodeObject(O),
            \+ (keywordOrAlias(O, K, '@id'), member(O, K, I)),
            concat('_:', O, I).

type(O, V) :- (nodeObject(O); valueObject(O)),
              keywordOrAlias(O, K, '@type'), member(O, K, T),
              ((plain(T), V = T); (array(T), member(T, _, V))) .

value(O, V) :- valueObject(O), member(O, '@value', V) .

lang(O, Lang) :- valueObject(O), member(O, '@language', Lang) .

item(O, O) :- \+ mapObject(O) .
item(O, V) :- mapObject(O), member(O, _, Op), item(Op, V) .

edge(O, K, V) :- nodeObject(O),
                 member(O, K, Op), \+ keywordOrAlias(O, K, _),
                 item(Op, V) .
edge(O, K, V) :- nodeObject(V),
                 member(V, '@reverse', Op), member(Op, K, Os),
                 item(Os, O) .
edge(O, K, V) :- nodeObject(V),
                 context(V, C), inverse(C, Kp, K),
                 member(V, Kp, Op),
                 item(Op, O) .

rdf(S, a, O, G) :- graph(G, NO), id(NO, S),
                   type(NO, V),
                   expandedIRI(NO, V, O) .
rdf(S, P, O, G) :- graph(G, NO), id(NO, S),
                   edge(NO, K, V),
                   expandedIRI(NO, K, P),
                   (id(V, O); value(V, O); expandedValue(NO, K, V, O)) .

rdf(S, P, O) :- rdf(S, P, O, _) .
