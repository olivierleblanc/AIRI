clear 
clc

path = fileparts(mfilename('fullpath'));
cd(path)
cd ..

config = ['.', filesep, 'config', filesep, 'airi_sim.json'];
dataFile = ['.', filesep, 'data', filesep, '3c353_meas_dt_1_seed_0.mat'];
groundtruth = ['.', filesep, 'data', filesep, '3c353_gdth.fits'];
resultPath = ['.', filesep, 'results']; 
algorithm = 'upnp-bm3d';
RunID = 0;

run_imager(config, 'dataFile', dataFile, 'algorithm', algorithm, 'resultPath', resultPath, 'groundtruth', groundtruth, 'runID', 0)