goal(p(X,Y), p(A,B)) :- A = X, B = Y.

% Set bounds, and also forbid a three positions to have to go around them
withinbounds(A,B) :- A > 0, B > 0, A < 10, B < 10, not((A = 3, B = 3)),not((A=3,B=4)),not((A=3, B = 5)).

% adj(p(X,Y),p(X1,Y1)) :- (X \= X1 ; Y \= Y1), X1 > 0, Y1 > 0, X1 < 10, Y1 < 10, abs(X - X1) < 2, abs(Y - Y1) < 2.
adj(p(X,Y),p(A,B)) :- ((A is X + 1, B is Y) ;
                      (A is X - 1, B is Y) ;
                      (A is X, B is Y + 1) ;
                      (A is X, B is Y - 1)), withinbounds(A,B).

% Builds child nodes
child([ParentCost, _, P], Target, [Cost, H, P1]) :- adj(P,P1), Cost is 1 + ParentCost, man(P1,Target,H).


% Heuristic, Manhattan distance
man(p(X,Y),p(X1,Y1), H) :-  H is abs(X - X1) + abs(Y - Y1).

% If the minimum of the nodes is the goal position, finished
search(Agenda, Target, Cost) :- min(Agenda, [[Cost, _, Pos]|_]), goal(Pos, Target).
% Otherwise, search node with lowest F value, and add its children and keep searching
search(Agenda, Target, C) :- min(Agenda, [Node|T]),
                                  setof(NewNode, child(Node, Target, NewNode), SortedChildren),
                                  append(SortedChildren, T, NewAgenda),
                                  search(NewAgenda, Target, C).

min([H|T], Result) :- hdMin(H, [], T, Result).
hdMin(H, S, [], [H|S]).
hdMin(C, S, [H|T], Result) :- lessthan(C, H), !, hdMin(C, [H|S], T, Result);
                              hdMin(H, [C|S], T, Result).

lessthan([G1, H1, _], [G2, H2, _]) :- F1 is G1 + H1, F2 is G2 + H2,
                                            F1 =< F2.

% We have a list of nodes (agenda), each node consisting of G (cost), H (heuristic, optimistic cost) and position
astar(Start, Target, C) :- search([[0, 0, Start]], Target, C).
