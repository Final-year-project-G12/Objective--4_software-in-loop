function Tw = amanowicz_case(P0, caseNo, shape, UA, Tstart, t, over)
%AMANOWICZ_CASE  One cool-down of the Amanowicz & Turski (2025) tank on the 10-node plant.
%
%   Tw = amanowicz_case(P0, caseNo, shape, UA, Tstart, t, over)
%
%   caseNo 1 = water only, 2 = water + 9 RT44HC capsules      shape 'volume' | 'area' | 'sv' (see benchmark_amanowicz.m)
%   UA     whole-tank loss coefficient [W/K]                   Tstart start water temperature [C]
%   t      output times [s] (0 : 300 : 7200)
%   over   optional struct overriding capsule constants (default: the frozen Objective 2 values)
%            .c      conduction constant c_cond (P(35), default 5)
%            .F      liquid convection factor (P(16), default 2)
% Setup, assumptions and sources: see the header of benchmark_amanowicz.m.
if nargin < 7, over = struct(); end
P = P0;
P(44) = 300;  P(6) = 30;  P(7) = 0;  P(29) = 0;                % 300 s "hour", 30 s steps, no axial conduction, shield off
P(2) = 1000;
Vw = {6.750, 4.050};  Vw = Vw{caseNo};                          % litres of water == kg
P(51:60) = Vw / 10;
P(71:80) = UA / 10;
if caseNo == 1
    P(61:70) = 0;
else
    nsph = 1;                                                    % spheres standing in for one cuboid capsule
    switch shape
        case 'volume', D = (6 * 300e-6 / pi)^(1/3);              % 300 mL sphere
        case 'area',   D = sqrt(2 * 300e-6 / 0.022 / pi);        % surface 2V/t
        case 'sv'                                                % same PCM mass AND same surface/volume (= 2/half-thickness)
            r_in = 3 * 0.011 / 2;                                % sphere with S/V = 3/r equal to the slab's 2/(11 mm)
            nsph = (0.200 / 800) / (4 / 3 * pi * r_in^3);        % 200 g of PCM at 800 kg/m3
            D = 2 * (r_in + 0.001);
    end
    P(22) = D;  P(23) = pi * D^2;
    P(20) = 0.001;  P(21) = 0.4;                                 % assumed plastic wall
    P(61:70) = 0.9 * nsph;                                       % 9 capsules (x nsph spheres each) over 10 identical nodes
    P(24) = 0.200 / nsph;                                        % kg PCM per sphere (paper: 200 g per capsule)
    P(14) = 0.040 * 1900 / 0.200;                                % wall heat capacity per kg PCM
    P(9) = 41;  P(10) = 44;  P(11) = 250e3;                      % melting range (paper), latent heat (Objective 1 database)
    P(12) = 2000;  P(13) = 2000;  P(15) = 0.2;                   % cp, conductivity (paper)
end
if isfield(over, 'c'),     P(35) = over.c;     end
if isfield(over, 'F'),     P(16) = over.F;     end
T = Tstart * ones(10, 1);
h = zeros(10, 1);
if caseNo == 2, h = (P(12) + P(14)) * 27 * ones(10, 1); end      % capsules start solid at 27 C
n = numel(t) - 1;
Tw = zeros(n + 1, 1);  Tw(1) = Tstart;
for k = 1:n
    [T, h] = pcm_plant_hour(0, 27, 0, 2, T, h, P);
    s = pcm_derive_state(T, h, P);
    Tw(k + 1) = s(3);
end
end
