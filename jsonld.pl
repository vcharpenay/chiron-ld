%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% JSON-LD for Prolog
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% JSON predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- dynamic member/3 .
:- dynamic root/2 .

object(O) :- member(O, _, _) .

array(O) :- object(O), \+ (member(O, K, _), \+ number(K)) .

plain(V) :- atom(V), \+ object(V) .

% JSON-LD context predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

iri(V) :- atom(V), sub_atom(V, 0, _, _, 'http:') . % TODO well-known schemes

keyword(V) :- atom(V), sub_atom(V, 0, _, _, '@') .

% note: the JSON-LD API does not consider contexts to be objects
contextObject(O) :- member(_, '@context', O), object(O) .
contextObject(O) :- member(Op, _, O), object(O), contextObject(Op) .

context(O, C) :- member(O, '@context', C) .
context(O, C) :- member(Op, _, O), context(Op, C) .

termMapping(C, K, V) :- member(C, K, V), (iri(V); keyword(V)) .
termMapping(C, K, V) :- member(C, K, O), member(O, '@id', V) .

range(C, K, V) :- member(C, K, O), member(O, '@type', V) .

keywordAlias(_, V, V) :- keyword(V) .
keywordAlias(O, V, Vp) :- context(O, C), termMapping(C, V, Vp), keyword(Vp) .

% JSON-LD main predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expandedIRI(_, I, I) :- iri(I) .
expandedIRI(O, T, I) :- context(O, C), termMapping(C, T, I) .

expandedValue(O, K, T, V) :- plain(T),
                             context(O, C),
                             (range(C, K, '@id'); range(C, K, '@vocab')),
                             expandedIRI(O, T, V) .
expandedValue(_, _, T, T) :- plain(T) . % TODO datatype, lang

graph(G, O) :- object(O), root(G, O) . % TODO named graphs
graph(G, Op) :- object(Op), member(O, _, Op), graph(G, O) .

valueObject(O) :- member(O, '@value', _) .

listObject(O) :- member(O, '@list', _) .

setObject(O) :- member(O, '@set', _) .

nodeObject(O) :- object(O),
                 \+ (valueObject(O);
                     listObject(O);
                     setObject(O);
                     contextObject(O)) .

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

rdf(S, a, O, G) :- graph(G, NO), nodeObject(NO), id(NO, S), type(NO, O) .
rdf(S, P, O, G) :- graph(G, NO), nodeObject(NO), id(NO, S),
                   member(NO, K, V), \+ keywordAlias(NO, K, _),
                   expandedIRI(NO, K, P),
                   (id(V, O); value(V, O); expandedValue(NO, K, V, O)) .

rdf(S, P, O) :- rdf(S, P, O, _) .

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% compacted(O, Op) :- object(O), context(O, C), termMapping(C, K, Kp),
%                     \+ ((member(O, K, V), member(Op, Ks, V), Kp \= Ks);
%                         (member(O, Ks, V), member(Op, Kp, V), K \= Ks);
%                         (member(O, K, V), member(Op, Kp, Vp), V \= Vp)) .

% expanded(O) :- object(O), \+ (member(O, K, _), \+ iri(K)) .
% expanded(O) :- compacted(_, O) .

% flattened(O, Op) :- TODO