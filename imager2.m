function imager2(path_uv_data, param_general, runID)
    
    fprintf('\nINFO: uv data file %s', path_uv_data);

    %% setting paths
    addpath([param_general.dirProject, filesep, 'lib', filesep, 'lib_utils', filesep]);
    util_set_path(param_general);

    % set result directory
    util_set_result_dir(path_uv_data, param_general, runID);
  
    %% Ground truth image
    gdth_img = fitsread(param_general.groundtruth);
    imSize = size(gdth_img);

    % figure();
    % imshow(gdth_img);
    % drawnow;

    %% Load uv-coverage data
    % [u, v, w, na] = generate_uv_coverage(frequency, nTimeSamples, obsTime, telescope, use_ROP);
    %%% TODO %%%
    load(path_uv_data, 'u_ab', 'v_ab', 'w_ab', 'na');

    uv_param = struct();
    uv_param.u = u_ab;
    uv_param.v = v_ab;
    uv_param.w = w_ab;
    % switch param_general.ROP_type
    %     case 'none'
    %         na = 27;
    %     case 'modul'
    %         na = 54;
    % end
    na = 27;
    uv_param.na = na;
    uv_param.nTimeSamples = size(u_ab, 1);

    % % Set pixel size
    % imPixelSize = util_set_pixel_size(param_general, path_uv_data);

    %% Set ROP parameters
    ROP_param = util_gen_ROP(na,... 
                            param_general.Nv,...
                            uv_param.nTimeSamples,... 
                            param_general.rv_type,... 
                            param_general.ROP_type,...
                            param_general.Nm);

    resolution_param.superresolution = param_general.superresolution;

    %% visibility operator and its adjoint
    [vis_op, adjoint_vis_op] = ops_visibility(uv_param, imSize, resolution_param, ROP_param);

    % %% perform the adjoint test
    % vis_op_vec = @(x) ( vis_op(reshape(x, imSize)) ); 
    % adjoint_raw_vis_op_vec = @(y) reshape(adjoint_raw_vis_op(y), [prod(imSize), 1]);
    % measop_shape = struct();
    % measop_shape.in = [prod(imSize), 1]
    % measop_shape.out = size(y);
    % adjoint_test(raw_vis_op_vec, adjoint_raw_vis_op_vec, vis_op_shape);

    %% data noise settings
    noiselevel = 'drheuristic'; % possible values: `drheuristic` ; `inputsnr`
    noise_param = struct();
    noise_param.noiselevel = noiselevel;
    expo_gdth = false;
    switch noiselevel
        case 'drheuristic'
            % dynamic range of the ground truth image
            log_sigma = rand() * (log10(1e-3) - log10(2e-6)) + log10(2e-6);
            sigma = 10^log_sigma;
            noise_param.targetDynamicRange = 1/sigma;
            if param_general.sigma0 > 0
                % Exponentiation of the ground truth image
                expo_gdth = true;
                pattern = '(?<=_id_)\d+(?=_dt_)';
                id = regexp(path_uv_data, pattern, 'match');
                seed = str2num(id{1});
                rng(seed, 'twister');
                expo_factor = util_solve_expo_factor(param_general.sigma0, sigma);
                fprintf('\nINFO: target dyanmic range set to %g', noise_param.targetDynamicRange);
                gdth_img = util_expo_im(gdth_img, expo_factor);
            end
        case 'inputsnr'
            % user-specified input signal to noise ratio
            noise_param.isnr = 40; % in dB
    end

    % figure(); imagesc(abs(gdth_img)); colorbar; title('Ground truth image');

    %% Generate the noiseless visibilities
    vis = vis_op(gdth_img);

    % Parameters for visibility weighting
    weight_param = struct();
    weight_param.weighting_on = param_general.flag_data_weighting;
    weighting_on = weight_param.weighting_on;
    if weighting_on
        load(path_uv_data, 'nWimag')
        weight_param.nWimag = nWimag;
    end

    % (eventually) apply ROPs 
    if ROP_param.use_ROP
        [D, ~] = op_ROP(ROP_param);
        y = D(vis);
    else
        y = vis;
    end

    % noise vector
    [tau, noise] = util_gen_noise(vis_op, adjoint_vis_op, imSize, y, noise_param, weight_param);
    
    % add noise to the data
    y = y + noise;

    %% (eventually) switch visibility weighting on
    % nW = (1 / tau) * ones(na^2*nTimeSamples,1);
    if weighting_on
        nW = (1 / tau) * nWimag;
        [W, ~] = op_vis_weighting(nW);
        y = W(y);
    end

    % Measurement operator and its adjoint
    [measop, adjoint_measop] = ops_measop(vis_op, adjoint_vis_op, weight_param, ROP_param);

    % Compute PSF
    imDimy = imSize(1); 
    imDimx = imSize(2);
    dirac = sparse(floor(imDimy./2) + 1, floor(imDimx./2) + 1, 1, imDimy, imDimx);
    PSF = adjoint_measop(measop(full(dirac)));
    PSFPeak = max(PSF, [], 'all');  clear dirac;
    fprintf('\nINFO: normalisation factor in RI, PSF peak value: %g', PSFPeak);


    %% Compute back-projected data: dirty image
    dirty = adjoint_measop(y);
    peak_est = max(dirty,[],'all') / PSFPeak;
    fprintf('\nINFO: dirty image peak value: %g', peak_est);

    figure(); imagesc(abs(dirty)); colorbar; title('Dirty image');
    drawnow;

    % Compute operator's spectral norm
    fprintf('\nComputing spectral norm of the measurement operator..')
    param_general.measOpNorm = op_norm(measop, adjoint_measop, imSize, 1e-6, 200, 0);
    fprintf('\nINFO: measurement op norm %f', param_general.measOpNorm);

    % if use primal-dual
    if ismember(param_general.algorithm, {'cairi', 'cpnp-bm3d'})
        [measop_cmp, adjoint_measop_cmp] = util_syn_meas_op_single(A, At, G, W, aW, true);
        param_general.measOpNormCmp = op_norm(measop_cmp, adjoint_measop_cmp, imSize, 1e-6, 200, 0);
        fprintf('\nINFO: measurement op norm for primal-dual %f', param_general.measOpNormCmp);
        clear measop_cmp adjoint_measop_cmp
    end

    %% Heuristic noise level
    heuristic_noise = 1 / sqrt(2 * param_general.measOpNorm);
    fprintf('\nINFO: heuristic noise level: %g', heuristic_noise);

    %% Set parameters for imaging and algorithms
    param_algo = util_set_param_algo(param_general, heuristic_noise, peak_est, numel(y));
    param_imaging = util_set_param_imaging(param_general, param_algo, imSize);

    %% Save dirty image, PSF and GT
    fitswrite(single(PSF), fullfile(param_imaging.resultPath, 'PSF.fits')); clear PSF;
    fitswrite(single(dirty), fullfile(param_imaging.resultPath, 'dirty_normalised.fits'));
    fitswrite(single(dirty./PSFPeak), fullfile(param_imaging.resultPath, 'dirty.fits'));
    fitswrite(gdth_img, fullfile(param_imaging.resultPath, 'GT.fits')) % ground truth

    %% INFO
    fprintf("\n________________________________________________________________\n")
    disp('param_algo:')
    disp(param_algo)
    disp('param_imaging:')
    disp(param_imaging)
    fprintf("________________________________________________________________\n")

    if param_imaging.flag_imaging
        %% Imaging
        switch param_algo.algorithm
            case 'airi'
                [MODEL, RESIDUAL] = airi(dirty, measop, adjoint_measop, param_imaging, param_algo);
            case 'upnp-bm3d'
                [MODEL, RESIDUAL] = upnp_bm3d(dirty, measop, adjoint_measop, param_imaging, param_algo);
            case 'cairi'
                [MODEL, RESIDUAL] = cairi(y, measop, adjoint_measop, aW, param_imaging, param_algo);
            case 'cpnp-bm3d'
                [MODEL, RESIDUAL] = cpnp_bm3d(y, measop, adjoint_measop, aW, param_imaging, param_algo);
        end

        %% Save final results
        fitswrite(MODEL, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_model_image.fits']))
        fitswrite(RESIDUAL, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_residual_dirty_image.fits']))
        fitswrite(RESIDUAL ./ PSFPeak, fullfile(param_imaging.resultPath, [param_algo.algorithm, '_residual_dirty_image_normalised.fits']))
        fprintf("\nFits files saved.")

        %% Final metrics
        fprintf('\nINFO: The standard deviation of the final residual dirty image %g', std(RESIDUAL, 0, 'all'))
        fprintf('\nINFO: The standard deviation of the normalised final residual dirty image %g', std(RESIDUAL, 0, 'all') / PSFPeak)
        fprintf('\nINFO: The ratio between the norm of the residual and the dirty image: ||residual|| / || dirty || =  %g', norm(RESIDUAL(:))./norm(dirty(:)))
        if isfield(param_imaging,'groundtruth') && ~isempty(param_imaging.groundtruth) && isfile(param_imaging.groundtruth)
            gdth_img = fitsread(param_imaging.groundtruth);
            rsnr = 20*log10( norm(gdth_img(:)) / norm(MODEL(:) - gdth_img(:)) );
            fprintf('\nINFO: The signal-to-noise ratio of the final reconstructed image %f dB', rsnr)
        end

    end
    fprintf('\nTHE END\n')
end