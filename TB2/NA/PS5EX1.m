n = [1,2,3,4,5];
h = 10.^(-n);
estimates = (exp(1+h)-exp(1))./h;
errors = exp(1)-estimates;
disp(estimates);
disp(errors);


%EX2
f = [2.287355, 2.677335, 3.094479, 3.535581,3.996196];

%disp(5*(f(5)-f(3)));
%disp(10*(f(4)-f(3)));
%disp((f(5)-f(1))/0.4);
%disp(5*(f(4)-f(2)));

% We're gonna use our estimate and h=0.1
% fp(x0) = 1/h*(2f(x0+h)-3/2*f(x0)-1/2*f(x0+2h))

aux = 4*f(4)-3*f(3)-f(5);
aux = aux/0.2;
disp(aux);
disp(5*(f(4)-f(2)));

% We use one step of Richardson extrapolation
aux = 4*f(4)-4*f(2)-f(5)+f(1);
aux = aux/0.4;
disp(aux);

