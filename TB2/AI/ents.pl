connected(bond_street,oxford_circus,central).
connected(oxford_circus,tottenham_court_road,central).
connected(bond_street,green_park,jubilee).
connected(green_park,charing_cross,jubilee).
connected(green_park,piccadilly_circus,piccadilly).
connected(piccadilly_circus,leicester_square,piccadilly).
connected(green_park,oxford_circus,victoria).
connected(oxford_circus,piccadilly_circus,bakerloo).
connected(piccadilly_circus,charing_cross,bakerloo).
connected(tottenham_court_road,leicester_square,northern).
connected(leicester_square,charing_cross,northern).

nearby(X,Y):-connected(X,Y,_L).
nearby(X,Y):-connected(X,Z,L),connected(Z,Y,L).

reachable(X,Y,[]):-connected(X,Y,_L).
reachable(X,Y,[Z|R]):-connected(X,Z,_L),reachable(Z,Y,R).

listlength([],0).
listlength([_Z|L],s(S)):-listlength(L,S).


married(X);bachelor(X):-man(X),adult(X).
man(peter).
adult(peter).
:-married(maria).
:-bachelor(maria).
man(paul).
:-bachelor(paul).
