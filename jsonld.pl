%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% JSON-LD for Prolog
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% FIXME not ISO Prolog (use asserta?)
:- use_module(library(tabling)).
:- table context/2 .

% JSON predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- dynamic member/3 .
:- dynamic root/2 .
:- dynamic object/1 .
:- dynamic array/1 .

% TODO distinguish between strings, booleans, numbers (dynamic predicates)
plain(V) :- atom(V), \+ object(V), V \= null .
plain(V) :- number(V) .

parent(O, Op) :- member(Op, _, O) .
parent(O, Op) :- member(Os, _, O), parent(Os, Op) .

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

localContext(C, C) :- contextDefinition(C) .
localContext(O, C) :- member(O, '@context', C), \+ contextDefinition(O) .
localContext(O, C) :- member(O, '@context', Cp), \+ contextDefinition(O),
                      array(Cp), member(Cp, _, C) .
localContext(O, C) :- member(Op, _, O), \+ contextDefinition(O), context(Op, C) .

propertyScopedContext(O, C) :- member(Op, K, O), \+ contextDefinition(O),
                               context(Op, Cp), range(Cp, K, C) .

typeScopedContext(O, C) :- (K = '@type'; keywordAlias(Cp, K, '@type')), member(O, K, T),
                           (localContext(O, Cp); propertyScopedContext(O, Cp)),
                           range(Cp, T, C),
                           \+ contextDefinition(O) .

context(O, C) :- localContext(O, C) .
context(O, C) :- propertyScopedContext(O, C) .
context(O, C) :- typeScopedContext(O, C) .

overrides(O, C, Cp) :- contextDefinition(C), contextDefinition(Cp), Cp \= C,
                       context(O, Cp), context(O, C),
                       nodeObject(O), parent(O, Op), nodeObject(Op),
                       context(Op, Cp) .

termMapping(C, K, V) :- contextDefinition(C), member(C, K, Vp),
                        ((plain(Vp), V = Vp); member(Vp, '@id', V)) .

range(C, K, Cp) :- member(C, K, V), member(V, '@context', Cp), contextDefinition(C) .

nullMapping(C, K) :- member(C, K, null), contextDefinition(C) .

vocabMapping(C, V) :- member(C, '@vocab', V), contextDefinition(C) .

vocabMapping(C, K, V) :- vocabMapping(C, V), \+ nullMapping(C, K) .

typeMapping(C, K, V) :- member(C, K, O), member(O, '@type', V), contextDefinition(C) .

inverse(C, K, Kp) :- member(C, K, O), member(O, '@reverse', Kp), contextDefinition(C) .

keywordAlias(C, V, Vp) :- termMapping(C, V, Vp), keyword(Vp) .

% JSON-LD main predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

activeContext(O, K, C) :- context(O, C),
                          \+ ((termMapping(C, K, _); vocabMapping(C, K, _)),
                              context(O, Cp),
                              (termMapping(Cp, K, _); vocabMapping(Cp, K, _)),
                              overrides(O, Cp, C)) .

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
expandedValue(O, K, T, T) :- plain(T),
                             \+ (context(O, C),
                                 (typeMapping(C, K, '@id'); typeMapping(C, K, '@vocab')))
                             . % TODO datatype, lang

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
keywordOrAlias(O, V, Vp) :- activeContext(O, V, C),
                            keywordAlias(C, V, Vp) .

id(O, I) :- nodeObject(O),
            keywordOrAlias(O, K, '@id'), member(O, K, I) .
id(O, I) :- nodeObject(O),
            \+ (keywordOrAlias(O, K, '@id'), member(O, K, I)),
            atom_concat('_:', O, I).

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
