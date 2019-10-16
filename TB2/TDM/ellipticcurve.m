v = (0:1:16);
ysquared = mod(v.^2,17);
pol = mod(v.^3+v+1,17);
for i=1:17
  for j=1:17
    if ysquared(j) == pol(i)
      disp([i-1,j-1]);
    end
  end
end  