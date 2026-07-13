%% The gamma table.
% Channel 1 on LCR4500: green 
clear
g = [
0       0.14
0.05	0.63
0.1     1.31
0.15	2.31
0.2     3.61
0.25	5.72
0.3     8.33
0.35	12.0
0.4     17.1
0.45	23.5
0.5     30.9
0.55	40.3
0.6     51.8
0.65	62.0
0.7     72.0
0.75	85.7
0.8     94.6
0.85	105.5
0.9     113.5
0.95	120.8
1.0     124.0];

plot(g(:,1), g(:,2))
title('Channel 1 Gamma')
xlabel('inputs')
ylabel('power [um]')

g(:,2) = g(:,2) - min(g(:,2));
g(:,2) = g(:,2)/max(g(:,2));
x_interp = (0:255)/255;
y_interp = interp1(g(:,1)',g(:,2)',x_interp,'spline');
% Compute the inverse gamma.
i_gamma = interp1(y_interp, x_interp, x_interp, 'linear');

out_gamma = zeros(size(i_gamma));
for jj = 1 : length(out_gamma)
    v_idx = find(abs(x_interp-i_gamma(jj)) == min(abs(x_interp-i_gamma(jj))));
    out_gamma(jj) = y_interp(v_idx);
end

% Print out the gamma ramp.
fid = fopen('channel_1_green_gamma_ramp.txt', 'w+');
for jj = 1 : length(i_gamma)
    fprintf(fid,'%6.7e\n',i_gamma(jj));
end
fclose(fid);

%%
%% The gamma table.
% Channel 2 on LCR4500: UV 
clear
g = [
0       0.14
0.05	0.2
0.1     0.29
0.15	0.43
0.2     0.60
0.25	0.87
0.3     1.19
0.35	1.68
0.4     2.30
0.45	3.14
0.5     4.08
0.55	5.26
0.6     6.77
0.65	8.46
0.7     10.12
0.75	11.67
0.8     13.2
0.85	14.4
0.9     15.4
0.95	16.4
1.0     16.7
];

plot(g(:,1), g(:,2))
title('Channel 2 Gamma')
xlabel('inputs')
ylabel('power [um]')

g(:,2) = g(:,2) - min(g(:,2));
g(:,2) = g(:,2)/max(g(:,2));
x_interp = (0:255)/255;
y_interp = interp1(g(:,1)',g(:,2)',x_interp,'spline');
% Compute the inverse gamma.
i_gamma = interp1(y_interp, x_interp, x_interp, 'linear');

out_gamma = zeros(size(i_gamma));
for jj = 1 : length(out_gamma)
    v_idx = find(abs(x_interp-i_gamma(jj)) == min(abs(x_interp-i_gamma(jj))));
    out_gamma(jj) = y_interp(v_idx);
end

% Print out the gamma ramp.
fid = fopen('channel_2_uv_gamma_ramp.txt', 'w+');
for jj = 1 : length(i_gamma)
    fprintf(fid,'%6.7e\n',i_gamma(jj));
end
fclose(fid);

%% The gamma table.
% Channel 3 on LCR4500: blue 
clear
g = [
0       0.14
0.05	0.55
0.1     1.16
0.15 	1.99
0.2     3.18
0.25 	4.88
0.3     6.87
0.35	10.02
0.4     14.1
0.45	15.9
0.5     22.2
0.55	33.0
0.60	36.6
0.65	50.2
0.7     54.2
0.75	65.8
0.8     76.8
0.85	86.2
0.9     90.4
0.95	96.6
1.0     99.6
];

plot(g(:,1), g(:,2))
title('Channel 3 Gamma')
xlabel('inputs')
ylabel('power [um]')

g(:,2) = g(:,2) - min(g(:,2));
g(:,2) = g(:,2)/max(g(:,2));
x_interp = (0:255)/255;
y_interp = interp1(g(:,1)',g(:,2)',x_interp,'spline');
% Compute the inverse gamma.
i_gamma = interp1(y_interp, x_interp, x_interp, 'linear');

out_gamma = zeros(size(i_gamma));
for jj = 1 : length(out_gamma)
    v_idx = find(abs(x_interp-i_gamma(jj)) == min(abs(x_interp-i_gamma(jj))));
    out_gamma(jj) = y_interp(v_idx);
end

% Print out the gamma ramp.
fid = fopen('channel_3_blue_gamma_ramp.txt', 'w+');
for jj = 1 : length(i_gamma)
    fprintf(fid,'%6.7e\n',i_gamma(jj));
end
fclose(fid);