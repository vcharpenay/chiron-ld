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

absoluteIRI(V) :- atom(V), sub_atom(V, 0, _, _, 'http:') . % FIXME well-known schemes

curie(V, Prefix, Name) :- \+ absoluteIRI(V),
                          sub_atom(V, N, Len, _, ':'),
                          sub_atom(V, 0, N, _, Prefix),
                          Np is N + Len,
                          sub_atom(V, Np, _, 0, Name) .

keyword(V) :- atom(V), sub_atom(V, 0, _, _, '@') . % FIXME list of keywords only

% note: the JSON-LD API does not consider contexts to be objects
contextObject(O) :- member(_, '@context', O), object(O) .
contextObject(O) :- member(Op, _, O), object(O), contextObject(Op) .

context(C, C) :- contextObject(C) .
context(O, C) :- member(O, '@context', C) .
context(O, C) :- member(Op, _, O), context(Op, C) .

termMapping(C, K, V) :- member(C, K, Vp), plain(Vp),
                        (expandedIRI(C, Vp, V); (keyword(Vp), V = Vp)) .
termMapping(C, K, V) :- member(C, K, O), member(O, '@id', Vp),
                        expandedIRI(C, Vp, V) .

range(C, K, V) :- member(C, K, O), member(O, '@type', V) .

inverse(C, K, Kp) :- member(C, K, O), member(O, '@reverse', Kp) .

keywordAlias(_, V, V) :- keyword(V) .
keywordAlias(O, V, Vp) :- context(O, C), termMapping(C, V, Vp), keyword(Vp) .

% indexContainer/1 causes significant slowdown of the program => term reordering
indexContainer(O) :- member(Os, '@container', '@index'),
                     member(C, K, Os),
                     member(Op, K, O), context(Op, C) .

% JSON-LD main predicates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expandedIRI(_, I, I) :- absoluteIRI(I) .
expandedIRI(O, T, I) :- curie(T, Prefix, Name),
                        context(O, C), termMapping(C, Prefix, NS),
                        atom_concat(NS, Name, I) .
expandedIRI(O, T, I) :- context(O, C), termMapping(C, T, I) .

expandedValue(O, K, T, V) :- plain(T),
                             context(O, C),
                             (range(C, K, '@id'); range(C, K, '@vocab')),
                             expandedIRI(O, T, V) .
expandedValue(_, _, T, T) :- plain(T) . % TODO datatype, lang

graph(G, O) :- root(G, O), object(O) . % TODO named graphs
graph(G, Op) :- object(Op), member(O, _, Op), graph(G, O) .

valueObject(O) :- member(O, '@value', _) .

listObject(O) :- member(O, '@list', _) .

setObject(O) :- member(O, '@set', _) .

reverseMap(O) :- member(_, '@reverse', O) .

containerObject(O) :- array(O) .
containerObject(O) :- indexContainer(O) .

nodeObject(O) :- object(O),
                 \+ (valueObject(O);
                     listObject(O);
                     setObject(O);
                     reverseMap(O);
                     containerObject(O);
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

item(O, O) :- \+ containerObject(O) .
item(O, V) :- containerObject(O), member(O, _, V) .
item(O, V) :- containerObject(O), member(O, _, Op), item(Op, V) .

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% compacted(O, Op) :- object(O), context(O, C), termMapping(C, K, Kp),
%                     \+ ((member(O, K, V), member(Op, Ks, V), Kp \= Ks);
%                         (member(O, Ks, V), member(Op, Kp, V), K \= Ks);
%                         (member(O, K, V), member(Op, Kp, Vp), V \= Vp)) .

% expanded(O) :- object(O), \+ (member(O, K, _), \+ iri(K)) .
% expanded(O) :- compacted(_, O) .

% flattened(O, Op) :- TODO