function C = load_campaign(regime)
%LOAD_CAMPAIGN  The tanks of the joint O4 plan, built by Objective 2's own setup
% (export_campaign.py -> <export>/campaign_cases.json), as plant structs K.
%
%   C = load_campaign(1)
%
% C.water_only   K of O2's water-only twin (same 50 L, same flow, capsules removed and their volume refilled)
% C.cases        struct array, one per PCM x flow: .key .pcm .flow_mult .rank .chosen .K .pcm_mass_kg .pump_power_w
% C.o1           Objective 1 top-3 records of this cluster (consensus-rank order)
% C.chosen_pcm   O2's PCM;  C.base = the O2 PCM at flow x1.0 (identical to the twin's own plant)
%
% Every K carries its own reset state (K.T0, K.h0: water 30 C, PCM solid at Ts - 5 K), which simulate_hours uses.
% For the water-only tank the interlock's PCM-side limits are switched off (P(31), P(33) = 1e6): with no capsules
% the "PCM temperature" is the mean water temperature and would latch a false 65 C fault (found in Rajasthan).
% The kernel itself only applies them to capsule nodes, so the physics does not change.
if nargin < 1 || isempty(regime), regime = 1; end
J = jsondecode(fileread(fullfile(twin_export_dir(regime), 'campaign_cases.json')));
raw = J.cases;
fn = fieldnames(raw);
C.regime = regime; C.chosen_pcm = J.chosen_pcm; C.o1 = J.o1_top3; C.design = J.design;
C.cases = struct('key', {}, 'pcm', {}, 'flow_mult', {}, 'rank', {}, 'chosen', {}, 'K', {}, 'pcm_mass_kg', {}, 'pump_power_w', {});
for i = 1:numel(fn)
    c = raw.(fn{i});
    if ~c.valid, warning('campaign case %s invalid in O2: %s', fn{i}, c.reason); continue; end
    K = toK(c);
    if c.water_only
        K.P(31) = 1e6; K.P(33) = 1e6;
        C.water_only = K; C.water_only_info = c;
        continue
    end
    rk = find(strcmp({C.o1.name}, c.pcm));
    C.cases(end+1) = struct('key', sprintf('%s_f%.1f', c.pcm, c.flow_mult), 'pcm', c.pcm, 'flow_mult', c.flow_mult, ...
        'rank', C.o1(rk).consensus_rank, 'chosen', strcmp(c.pcm, J.chosen_pcm), 'K', K, ...
        'pcm_mass_kg', c.pcm_mass_kg, 'pump_power_w', c.pump_power_w);
end
ib = find([C.cases.chosen] & abs([C.cases.flow_mult] - 1) < 1e-9, 1);
C.base = C.cases(ib);
end

function K = toK(c)
K.P = c.P(:); K.m_w = c.m_w_kg(:); K.n_caps = c.n_caps(:); K.loss_ua = c.loss_ua_W_K(:);
K.demand24 = c.demand_kg_by_hour(:);
K.coll = [c.collector.area_m2; c.collector.fr_tau_alpha; c.collector.fr_ul_W_m2K; c.collector.I_cutoff_Wm2];
K.N = numel(K.m_w); K.T0 = c.T0_C(:); K.h0 = c.h0_J_kg(:);
end
