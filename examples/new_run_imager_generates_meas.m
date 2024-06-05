clear all;
clc;

path = fileparts(mfilename('fullpath'));
cd(path)
cd ..

config = ['.', filesep, 'config', filesep, 'new_config_ROP.json'];
uvFile = ['.', filesep, 'data', filesep, 'obs_id_1000_dt_11.72_freqratio_1.85_nfreq_1_rotation_4.89.mat'];
% uvFile = ['.', filesep, 'data', filesep, 'uv_id_1377_dt_7.83_freqratio_1.10_nfreq_3_rotation_206.51.mat'];
groundtruth = ['.', filesep, 'data', filesep, '3c353.fits'];
resultPath = ['.', filesep, 'results'];
% resultPath = '';
runID = 0;

run_imager2(config, 'uvFile', uvFile, 'resultPath', resultPath, 'groundtruth', groundtruth, 'runID', runID)