p = @(x) x.^3+4*x.^2-10;
pol = [1,4,0,-10];
g = @(x) sqrt(10-x.^3)/2;

seq = [0: 0.01 : 1];
aitseq = seq;

seq(1) = 1.5;
seq(2) = g(seq(1));

for i = 1:30
  seq(i+2) = g(seq(i+1));
  aitseq(i) = seq(i)-(seq(i+1)-seq(i))^2/(seq(i+2)-2*seq(i+1)+seq(i));
 end
 disp(seq(1:7));
 disp(p(seq(1:7)));  % show the accuracy of the sixth iteration of fixed point methods
 disp(p(aitseq(1:7))); % show the accuracy of aitken's method's estimate
 disp(roots(pol)-aitseq(7));
 