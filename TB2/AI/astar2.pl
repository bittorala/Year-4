goal(p(X,Y), p(A,B)) :- A = X, B = Y.

% Set bounds, and also forbid a three positions to have to go around them
withinbounds(A,B) :- A > 0, B > 0, A < 10, B < 10, not((A = 3, B = 3)),not((A=3,B=4)),not((A=3, B = 5)).

% adj(p(X,Y),p(X1,Y1)) :- (X \= X1 ; Y \= Y1), X1 > 0, Y1 > 0, X1 < 10, Y1 < 10, abs(X - X1) < 2, abs(Y - Y1) < 2.
adj(p(X,Y),p(A,B)) :- ((A is X + 1, B is Y) ;
                      (A is X - 1, B is Y) ;
                      (A is X, B is Y + 1) ;
                      (A is X, B is Y - 1)), withinbounds(A,B).

% Builds child nodes
child([_,PG, PPos,PPath], Target, [CF,CG,CPos,[CPos|PPath]]) :- adj(PPos,CPos), CG is PG + 1, man(CPos,Target,H), CF is CG + H.


% Heuristic, Manhattan distance
man(p(X,Y),p(X1,Y1), H) :-  H is abs(X - X1) + abs(Y - Y1).

findMin([H|T],Result) :- findMinAux(H,[],T,Result).
findMinAux(Smallest,Seen,[],[Smallest|Seen]).
findMinAux(Smallest,Seen,[H|T],Result) :- leq(H,Smallest),!,findMinAux(H,[Smallest|Seen],T,Result) ; findMinAux(Smallest,[H|Seen],T,Result).
leq([F1,_,_,_],[F2,_,_,_]) :- F1 =< F2.

% If the minimum of the nodes is the goal position, finished
search(Agenda, Target, Cost,RPath) :- findMin(Agenda,[M|_]), M = [_,Cost,Pos,RevPath], goal(Pos, Target),RPath = RevPath.
% Otherwise, search node with lowest F value, and add its children and keep searching
search(Agenda, Target, C,RR) :- findMin(Agenda,[M|T]),
                            setof(Child, child(M, Target, Child), SortedChildren),
                            append(SortedChildren, T, NewAgenda),
                            search(NewAgenda, Target, C,RR).

% We have a list of nodes (agenda), each node consisting of F, G and Position
astar(Start, Target, C,RPath) :- search([[0, 0, Start,[Start]]], Target, C,RPath).
