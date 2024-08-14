function [] = util_save_results(MODEL, RESIDUAL, PSFPeak, param_imaging, param_algo)
    
    fitswrite(MODEL, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_model_image.fits'])) % model estimate
    fitswrite(RESIDUAL, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_residual_dirty_image.fits'])) % back-projected residual data
    fitswrite(RESIDUAL ./ PSFPeak, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_residual_dirty_image_normalised.fits'])) % normalised back-projected residual data
    fprintf("\nFits files saved.")
end