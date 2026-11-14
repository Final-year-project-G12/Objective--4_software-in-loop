function run_arm()
%RUN_ARM  Item B: the arm comparison over 2023, water-only tank / PCM + B0 / PCM + DQN (three_arm_2023) and with the SAC (four_arm_2023 for regimes 0, 1, 2).
here = fileparts(mfilename('fullpath')); addpath(here);
three_arm_2023;
for r = 0:2, four_arm_2023(r); end
end
