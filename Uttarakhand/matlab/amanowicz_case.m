function Tw = amanowicz_case(K0, caseNo, shape, UA, Tstart, t)
%AMANOWICZ_CASE  One cool-down of the Amanowicz & Turski (2025) tank on the Uttarakhand 10-node plant.
% Same setup as Rajasthan's amanowicz_case.m (see benchmark_amanowicz.m for sources and assumptions).
%
%   caseNo 1 = water only, 2 = water + 9 RT44HC capsules     shape 'volume' | 'area' | 'sv'
%   UA     whole-tank loss coefficient [W/K]                  Tstart start water temperature [C]
%   t      output times [s] (0 : 300 : 7200)
% The frozen Objective 2 capsule constants (conduction c = P(35), liquid enhancement P(16)) are NOT changed.
K = K0;
K.hour_s = 300; K.P(6) = 30; K.P(7) = 0; K.P(29) = 0;      % 300 s "hour", 30 s steps, no axial conduction, shield off
K.P(2) = 1000; K.demand24 = zeros(24, 1);
Vw = [6.750, 4.050]; Vw = Vw(caseNo);                       % litres of water == kg
K.N = 10; K.m_w = Vw / 10 * ones(10, 1); K.loss_ua = UA / 10 * ones(10, 1);
if caseNo == 1
    K.n_caps = zeros(10, 1);
else
    nsph = 1;
    switch shape
        case 'volume', D = (6 * 300e-6 / pi)^(1/3);              % sphere of the same 300 mL volume
        case 'area',   D = sqrt(2 * 300e-6 / 0.022 / pi);        % sphere with the cuboid's surface 2V/t
        case 'sv'                                                % same PCM mass AND surface/volume as the 22 mm slab
            r_in = 3 * 0.011 / 2;
            nsph = (0.200 / 800) / (4 / 3 * pi * r_in^3);
            D = 2 * (r_in + 0.001);
    end
    K.P(22) = D; K.P(23) = pi * D^2;
    K.P(20) = 0.001; K.P(21) = 0.4;                              % assumed 1 mm plastic wall
    K.n_caps = 0.9 * nsph * ones(10, 1);                          % 9 capsules (x nsph spheres) over 10 identical nodes
    K.P(24) = 0.200 / nsph;                                      % kg PCM per sphere (paper: 200 g per capsule)
    K.P(14) = 0.040 * 1900 / 0.200;                              % wall heat capacity per kg PCM
    K.P(9) = 41; K.P(10) = 44; K.P(11) = 250e3;                  % melting range (paper), latent heat (O1 database)
    K.P(12) = 2000; K.P(13) = 2000; K.P(15) = 0.2;               % cp, conductivity (paper)
end
T = Tstart * ones(10, 1); h = zeros(10, 1);
if caseNo == 2, h = (K.P(12) + K.P(14)) * 27 * ones(10, 1); end   % capsules start solid at the 27 C lab temperature
n = numel(t) - 1; Tw = zeros(n + 1, 1); Tw(1) = Tstart;
for k = 1:n
    [T, h, rec] = pcm_plant_hour(0, 27, 0, 0, T, h, K);
    Tw(k + 1) = rec(2);
end
end
