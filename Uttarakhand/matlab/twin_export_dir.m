function d = twin_export_dir(regime)
%TWIN_EXPORT_DIR  Export folder of a regime (same convention as Tamil Nadu):
% regime 0 -> ../export, regime k -> ../export_r<k>.
here = fileparts(mfilename('fullpath'));
if regime == 0
    d = fullfile(here, '..', 'export');
else
    d = fullfile(here, '..', sprintf('export_r%d', regime));
end
if ~isfolder(d)
    error('twin:noExport', ['%s missing - run Uttarakhand/export_from_python.py --regime %d with the ' ...
        'Uttarakhand Objective 3 venv first'], d, regime);
end
end
