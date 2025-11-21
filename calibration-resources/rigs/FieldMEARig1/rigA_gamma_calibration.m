% The gamma table.
% Channel 1 on LCR4500: red 
clear
r = [
0       1.03
0.05	2.69
0.1     4.97
0.15	8.14
0.2     13.1
0.25	19.7
0.3     28.1
0.35	40.4
0.4     56.8
0.45	77.3
0.5     100.7
0.55	131.0
0.6     172
0.65	207
0.7     242
0.75	288
0.8     327
0.85	360
0.9     385
0.95	410
1.0     420];

plot(r(:,1), r(:,2))
title('Channel 1 Gamma')
xlabel('inputs')
ylabel('power [uW]')

r(:,2) = r(:,2) - min(r(:,2));
r(:,2) = r(:,2)/max(r(:,2));
x_interp = (0:255)/255;
y_interp = interp1(r(:,1)',r(:,2)',x_interp,'spline');
% Compute the inverse gamma.
i_gamma = interp1(y_interp, x_interp, x_interp, 'linear');

out_gamma = zeros(size(i_gamma));
for jj = 1 : length(out_gamma)
    v_idx = find(abs(x_interp-i_gamma(jj)) == min(abs(x_interp-i_gamma(jj))));
    out_gamma(jj) = y_interp(v_idx);
end

% Print out the gamma ramp.
fid = fopen('channel_1_red_gamma_ramp.txt', 'w+');
for jj = 1 : length(i_gamma)
    fprintf(fid,'%6.7e\n',i_gamma(jj));
end
fclose(fid);

%%
%% The gamma table.
% Channel 2 on LCR4500: green 
clear
g = [
0       1.03
0.05	5.7
0.1     12.2
0.15	21.6
0.2     35.7
0.25	53.1
0.3     76.4
0.35	110
0.4     158
0.45	216
0.5     286
0.55	365
0.6 	474
0.65	595
0.7     708
0.75	816
0.8 	918
0.85	998
0.9 	1069
0.95	1123
1.0     1146
];

plot(g(:,1), g(:,2))
title('Channel 2 Gamma')
xlabel('inputs')
ylabel('power [uW]')

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
fid = fopen('channel_2_green_gamma_ramp.txt', 'w+');
for jj = 1 : length(i_gamma)
    fprintf(fid,'%6.7e\n',i_gamma(jj));
end
fclose(fid);

%% The gamma table.
% Channel 3 on LCR4500: blue 
clear
b = [
0       1.03
0.05	2.63
0.1     5.0
0.15	8.36
0.2     12.8
0.25	19.6
0.3     27.6
0.35	39.9
0.4     55.1
0.45	63.6
0.5     87.7
0.55	130
0.6     140.7
0.65	202
0.7 	217
0.75	263
0.8 	308
0.85	344
0.9 	362
0.95	368
1.0 	397	
];

plot(b(:,1), b(:,2))
title('Channel 3 Gamma')
xlabel('inputs')
ylabel('power [um]')

b(:,2) = b(:,2) - min(b(:,2));
b(:,2) = b(:,2)/max(b(:,2));
x_interp = (0:255)/255;
y_interp = interp1(b(:,1)',b(:,2)',x_interp,'spline');
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