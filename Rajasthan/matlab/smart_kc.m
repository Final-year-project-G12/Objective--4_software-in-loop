function kc = smart_kc(ghi, clear)
%SMART_KC  Causal clear-sky index of Objective 3's smart-persistence forecast (o3/environment/forecast.py::clear_sky_index).
%
%   kc = smart_kc(GHI, GHI_clear)      both [n x 1] in W/m2, one value per hour
%
%   Kc(t) = clip(GHI(t) / GHI_clear(t), 0, 1.2) when GHI_clear(t) > 20 W/m2, otherwise the last daytime value (1.0 before the first one).
%   Kc(t) uses hours <= t only. The forecast made at hour t for hour t + h is  Kc(t) * GHI_clear(t + h)  (0 past the end of the year);
%   simulate_hours(..., clearsky) builds the 1-3 h look-ahead of the observation from it.
ghi = ghi(:);  clear = clear(:);
n = numel(ghi);
day = clear > 20;
raw = min(max(ghi ./ (day .* clear + ~day), 0), 1.2);
kc = ones(n, 1);                         % KC_INIT = 1.0 before the first daytime hour
last = 0;
for t = 1:n
    if day(t), last = t; end
    if last > 0, kc(t) = raw(last); end
end
end
