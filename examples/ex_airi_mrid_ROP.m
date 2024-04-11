clear 
clc

path = fileparts(mfilename('fullpath'));
cd(path)
cd ..

config = ['.', filesep, 'config', filesep, 'airi_sim_ROP.json'];
dataFile = ['.', filesep, 'data', filesep, 'ngc6543a_data_ROP_batch_unitary500.mat'];
groundtruth = ['.', filesep, 'data', filesep, 'ngc6543a_gt.fits'];
resultPath = ['.', filesep, 'results']; 
algorithm = 'airi';
shelf_pth = ['.', filesep, 'airi_denoisers', filesep, 'shelf_mrid.csv'];
RunID = 1;

run_imager(config, 'dataFile', dataFile, 'algorithm', algorithm, 'resultPath', resultPath, 'dnnShelfPath', shelf_pth, 'groundtruth', groundtruth, 'runID', RunID)