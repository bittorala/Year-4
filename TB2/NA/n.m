
f = @(x,y) x-1;
g = @(x,y) x-y;
G = @(x,y) f(x,y)*f(x,y) + g(x,y)*g(x,y);

disp(G(0,0));