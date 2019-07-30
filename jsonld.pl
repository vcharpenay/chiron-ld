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

contextDefinition(O) :- member(_, '@context', O), object(O) .
contextDefinition(O) :- member(Op, _, O), object(O), contextDefinition(Op) .

context(C, C) :- contextDefinition(C) .
context(O, C) :- member(O, '@context', C) .
context(O, C) :- member(O, '@context', Cp), array(Cp), member(Cp, _, C) .
context(O, C) :- object(O), member(Op, _, O), context(Op, C) .
context(O, C) :- member(Op, K, O), context(Op, Cp), range(Cp, K, C) .

overrides(C, Cp) :- context(O, Cp), context(O, C),
                    Cp \= C, nodeObject(O),
                    member(Op, _, O), context(Op, Cp) .

termMapping(C, K, V) :- member(C, K, Vp),
                        ((plain(Vp), Vs = Vp); member(Vp, '@id', Vs)),
                        expandedIRI(C, Vs, V) .

range(C, K, Cp) :- member(C, K, V), member(V, '@context', Cp) .

nullMapping(C, K) :- member(C, K, null) .

vocabMapping(C, V) :- member(C, '@vocab', V) .

vocabMapping(C, K, V) :- vocabMapping(C, V), \+ nullMapping(C, K) .

typeMapping(C, K, V) :- member(C, K, O), member(O, '@type', V) .

inverse(C, K, Kp) :- member(C, K, O), member(O, '@reverse', Kp) .

keywordAlias(_, V, V) :- keyword(V) .
keywordAlias(O, V, Vp) :- context(O, C), keyword(Vp),
                          member(C, V, Vp) .
keywordAlias(O, V, Vp) :- context(O, C), keyword(Vp),
                          member(C, V, Op), member(Op, '@id', Vp) .

indexMap(O) :- member(Os, '@container', '@index'),
                     member(C, K, Os),
                     member(Op, K, O), context(Op, C) .

% JSON-LD main predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

activeContext(O, K, C) :- context(O, C),
                          \+ (context(O, Cp), overrides(Cp, C),
                              (termMapping(Cp, K, _); vocabMapping(Cp, K, _)),
                              (termMapping(C, K, _); vocabMapping(C, K, _))) .

expandedIRI(_, I, I) :- keyword(I) .
expandedIRI(_, I, I) :- absoluteIRI(I) .
expandedIRI(O, T, I) :- curie(T, Prefix, Name),
                        activeContext(O, Prefix, C), termMapping(C, Prefix, NS),
                        atom_concat(NS, Name, I) .
expandedIRI(O, T, I) :- \+ keyword(T), \+ absoluteIRI(T), \+ curie(T, _, _),
                        activeContext(O, T, C),
                        vocabMapping(C, T, V),
                        atom_concat(V, T, I) .
expandedIRI(O, T, I) :- activeContext(O, T, C), termMapping(C, T, I) .

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

id(O, I) :- nodeObject(O),
            keywordAlias(O, K, '@id'), member(O, K, I) .
id(O, I) :- nodeObject(O),
            \+ (keywordAlias(O, K, '@id'), member(O, K, I)),
            concat('_:', O, I).

type(O, I) :- (nodeObject(O); valueObject(O)),
              keywordAlias(O, K, '@type'), member(O, K, T),
              ((plain(T), V = T); (array(T), member(T, _, V))),
              expandedIRI(O, V, I) .

value(O, V) :- valueObject(O), member(O, '@value', V) .

lang(O, Lang) :- valueObject(O), member(O, '@language', Lang) .

item(O, O) :- \+ mapObject(O) .
item(O, V) :- mapObject(O), member(O, _, Op), item(Op, V) .

edge(O, K, V) :- nodeObject(O),
                 member(O, K, Op), \+ keywordAlias(O, K, _),
                 item(Op, V) .
edge(O, K, V) :- nodeObject(V),
                 member(V, '@reverse', Op), member(Op, K, Os),
                 item(Os, O) .
edge(O, K, V) :- nodeObject(V),
                 context(V, C), inverse(C, Kp, K),
                 member(V, Kp, Op),
                 item(Op, O) .

rdf(S, a, O, G) :- graph(G, NO), id(NO, S), type(NO, O) .
rdf(S, P, O, G) :- graph(G, NO), id(NO, S),
                   edge(NO, K, V),
                   expandedIRI(NO, K, P),
                   (id(V, O); value(V, O); expandedValue(NO, K, V, O)) .

rdf(S, P, O) :- rdf(S, P, O, _) .
