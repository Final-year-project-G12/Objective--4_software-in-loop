function R = capsule_single(P0, name, over, resin)
%CAPSULE_SINGLE  One capsule held in a fixed-temperature bath, on the twin's own plant (constrained melting).
%
%   R = capsule_single(tw.P, 'tan2009' | 'dong2022', over, resin)
%
% The same kernel (pcm_plant_hour.m) as every other result, configured as ONE capsule in a bath so big that its
% temperature does not move: 10 identical nodes of 1e5 kg water, no loss, no flow, film resistance switched off
% (water conductivity 1e9), so the capsule surface sits at the bath temperature. This is the set-up of
% Objective 2's "frozen lumped model against the two experiments" (docs/07_OPENFOAM_VALIDATION.md 2.5,
% rj_openfoam/results/of_lumped_vs_benchmarks.csv: c = 5, F = 2 gives t25 = 71.5 min for Tan and
% 38.1 / 78.1 / 99.1 / 112.2 min for Dong), which check_capsule_regression in calibrate_capsule.m repeats.
%
%   over    struct, optional: .c (P(35), default 5)  .F (P(16), default 2)
%   resin   Dong only: true puts the 2 mm resin shell (k 0.4 W/mK, Dong Table 2) between bath and PCM (default false,
%           the Objective 2 set-up with the bath on the PCM surface)
%
% Cases (all n-octadecane; Tan 2009 Table 1, Dong 2022 Table 2 via Objective 2's document):
%   tan2009   R 50.83 mm, rho 772, bath 40 C, start 27.2 C (Tm - 1 K), no wall (Objective 2: the ~1.5 mm glass is not modelled)
%   dong2022  R 34.3 mm, rho 774.5, bath 38.2 C (311.35 K), start 27.2 C (300.35 K)
%   both      Tm 28.2 C (band 27.2-29.2 C), L 243.5 kJ/kg, cp 2330 J/kgK both phases, k 0.1505 W/mK
%
% Returns R.t_min, R.f (melt fraction), R.tq = [t25 t50 t75 t90] in minutes (NaN if not reached), R.name.
if nargin < 3 || isempty(over), over = struct(); end
if nargin < 4 || isempty(resin), resin = false; end
switch name
    case 'tan2009',  Rp = 0.05083;  rho = 772;    Tb = 40;    tend = 200;
    case 'dong2022', Rp = 0.0343;   rho = 774.5;  Tb = 38.2;  tend = 200;
    otherwise, error('capsule_single: unknown case %s', name);
end
P = P0;
P(6) = 5;  P(44) = 60;  P(7) = 0;  P(29) = 0;                    % 5 s steps, 60 s "hour", no conduction between nodes, shield off
P(2) = 1000;  P(17) = 1e9;                                       % film resistance -> 0
P(51:60) = 1e5;  P(71:80) = 0;                                   % huge bath, no losses
twall = 1e-9;  kwall = 200;
if strcmp(name, 'dong2022') && resin, twall = 0.002;  kwall = 0.4; end
D = 2 * (Rp + twall);
P(20) = twall;  P(21) = kwall;  P(22) = D;  P(23) = pi * D^2;
P(61:70) = 0.1;                                                  % one capsule in total
P(24) = rho * 4 / 3 * pi * Rp^3;                                 % PCM mass of the capsule
P(14) = 0;                                                       % no wall heat capacity (Objective 2 set-up)
P(9) = 27.2;  P(10) = 29.2;  P(11) = 243.5e3;  P(12) = 2330;  P(13) = 2330;  P(15) = 0.1505;
if isfield(over, 'c'), P(35) = over.c; end
if isfield(over, 'F'), P(16) = over.F; end
T = Tb * ones(10, 1);
h = (P(12) + P(14)) * 27.2 * ones(10, 1);                        % solid, 1 K below Tm
n = tend;
f = zeros(n + 1, 1);
for k = 1:n
    [T, h] = pcm_plant_hour(0, 25, 0, 2, T, h, P);
    s = pcm_derive_state(T, h, P);
    f(k + 1) = s(5);
end
R.name = name;  R.t_min = (0:n)';  R.f = f;
R.tq = nan(1, 4);
lv = [0.25 0.5 0.75 0.9];
for q = 1:4
    k = find(f >= lv(q), 1);
    if ~isempty(k) && k > 1
        R.tq(q) = R.t_min(k - 1) + (lv(q) - f(k - 1)) / (f(k) - f(k - 1));
    end
end
end
