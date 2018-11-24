function [p_fp_ps, debug] = four_points_detect_LoG(array,opts)
    % Obtains the locations of the four points (fiducial markers) around 
    % the calibration board.
    % 
    % Inputs:
    %   
    %
    % Outputs:
    %   
    %
    
    % Get blobs ----------------------------------------------------------%

    blobs = alg.blob_detect_LoG(array,opts);

    % Refine ellipses ----------------------------------------------------%
    
    % For theta, sample 1 more and then remove it; this allows [0 2*pi)
    theta_samples = linspace(0,2*pi,opts.ellipse_detect_num_samples_theta+1)';
    theta_samples(end) = [];  
    
    % Initialize ellipses
    ellipses = zeros(0,5); 
    
    % Iterate over blobs
    for i = 1:size(blobs,1)      
        % Get initial ellipse --------------------------------------------%
        
        e = blobs(i,:)';
        
        % Get "cost" array -----------------------------------------------%
        
        % Has high values along edge of ellipse. Use smoothed, upsampled
        % sub array to compute gradients in order to improve convergence.
        
        % Get bounding box
        e_bb = e;
        e_bb(3) = 3*e_bb(3);
        e_bb(4) = 3*e_bb(4);
        bb_sub_array = alg.bb_ellipse(e_bb);
        bb_sub_array(1,:) = floor(bb_sub_array(1,:));
        bb_sub_array(2,:) = ceil(bb_sub_array(2,:));
        
        % Make sure sub array is in bounds
        if bb_sub_array(1,1) < 1 || bb_sub_array(2,1) > size(array,2) || ...
           bb_sub_array(1,2) < 1 || bb_sub_array(2,2) > size(array,1)
            continue
        end
        
        % Grab sub array
        sub_array = array(bb_sub_array(1,2):bb_sub_array(2,2), ...
                          bb_sub_array(1,1):bb_sub_array(2,1));
        
        % Get cost array
        sf_cost = opts.ellipse_detect_sf_cost;
        sub_array_up = imresize(alg.gauss_array(sub_array,e(4)/2),sf_cost); % Use minor axis to blur
        sub_array_c = sqrt(alg.grad_array(sub_array_up,'x').^2 + ...
                           alg.grad_array(sub_array_up,'y').^2);
        sub_array_c = alg.normalize_array(sub_array_c,'min-max');
        
        % Get gradients of cost array
        sub_array_c_dx = alg.grad_array(sub_array_c,'x');
        sub_array_c_dy = alg.grad_array(sub_array_c,'y');
                                       
        % Get interpolants for speed
        I_sub_array_c = griddedInterpolant({1:size(sub_array_c,1),1:size(sub_array_c,2)}, ...
                                           sub_array_c, ...
                                           opts.ellipse_detect_interp, ...
                                           'none');
        I_sub_array_c_dx = griddedInterpolant({1:size(sub_array_c_dx,1),1:size(sub_array_c_dx,2)}, ...
                                              sub_array_c_dx, ...
                                              opts.ellipse_detect_interp, ...
                                              'none');
        I_sub_array_c_dy = griddedInterpolant({1:size(sub_array_c_dy,1),1:size(sub_array_c_dy,2)}, ...
                                              sub_array_c_dy, ...
                                              opts.ellipse_detect_interp, ...
                                              'none');          
        
        % Perform gradient ascent with backtracking ----------------------%
        
        % Based on tests that I've done, lambda appears to stay relatively
        % constant, so I used the lambda technique from the
        % Levenberg-Marquardt method.
        
        % Initialize lambda        
        lambda = opts.ellipse_detect_lambda_init;
                
        % Iterate
        for it = 1:opts.ellipse_detect_it_cutoff      
            % Get previous coordinates
            e_prev = e;
            p_prev = alg.sample_ellipse(e_prev,theta_samples);
            x_prev = sf_cost*(p_prev(:,1)-bb_sub_array(1,1)+1 - 1/2*(1-1/sf_cost));
            y_prev = sf_cost*(p_prev(:,2)-bb_sub_array(1,2)+1 - 1/2*(1-1/sf_cost));
            
            % Compute gradient at e_prev
            dc_dx = I_sub_array_c_dx(y_prev,x_prev);
            dc_dy = I_sub_array_c_dy(y_prev,x_prev);
            dx_de = [ones(numel(theta_samples),1)  zeros(numel(theta_samples),1) cos(e_prev(5))*cos(theta_samples) -sin(e_prev(5))*sin(theta_samples) -e_prev(3)*sin(e_prev(5))*cos(theta_samples)-e_prev(4)*cos(e_prev(5))*sin(theta_samples)];
            dy_de = [zeros(numel(theta_samples),1) ones(numel(theta_samples),1)  sin(e_prev(5))*cos(theta_samples)  cos(e_prev(5))*sin(theta_samples)  e_prev(3)*cos(e_prev(5))*cos(theta_samples)-e_prev(4)*sin(e_prev(5))*sin(theta_samples)];
            grad = sum(dc_dx.*dx_de + dc_dy.*dy_de)';
            
            % Get new coordinates
            e = e_prev + lambda*grad;
            p = alg.sample_ellipse(e,theta_samples);
            x = sf_cost*(p(:,1)-bb_sub_array(1,1)+1 - 1/2*(1-1/sf_cost));
            y = sf_cost*(p(:,2)-bb_sub_array(1,2)+1 - 1/2*(1-1/sf_cost));
            
            % Perform backtracking 
            cost_init = sum(I_sub_array_c(y_prev,x_prev));
            while any(x < 1 | x > size(sub_array_c,2) | ...
                      y < 1 | y > size(sub_array_c,1)) || ...
                  sum(I_sub_array_c(y',x')) < cost_init+(1/2)*lambda*dot(grad,grad) % Backtracking guaranteed to exit this condition eventually
                               
                % Decrease step
                lambda = lambda/opts.ellipse_detect_lambda_factor;
                
                if lambda <= eps('single')
                    % This will already be a very, very small step, so just
                    % exit
                    e = e_prev;
                    x = x_prev;
                    y = y_prev;
                    break
                end
                
                % Get new coordinates
                e = e_prev + lambda*grad;
                p = alg.sample_ellipse(e,theta_samples);
                x = sf_cost*(p(:,1)-bb_sub_array(1,1)+1 - 1/2*(1-1/sf_cost));
                y = sf_cost*(p(:,2)-bb_sub_array(1,2)+1 - 1/2*(1-1/sf_cost));
            end
                                
            % Increase step for next iteration
            lambda = lambda*opts.ellipse_detect_lambda_factor;
            
            % Exit if the ellipse went out of the bounding box
            if any(x < 1 | x > size(sub_array_c,2) | ...
                   y < 1 | y > size(sub_array_c,1))
                e(:) = NaN;
                break
            end
            
            % Exit if change in distance is small
            diff_norm = norm(e-e_prev);            
            if diff_norm < opts.ellipse_detect_norm_cutoff
                break
            end
        end
                     
        % Check if any params are NaNs
        if any(isnan(e))
            continue
        end
                
        % Before storing ellipse, make sure there isn't another ellipse 
        % near this one. This is ad-hoc clustering and is typically 
        % "good enough"
        dist_d = sqrt((ellipses(:,1)-e(1)).^2 + ...
                      (ellipses(:,2)-e(2)).^2);
        dist_r1 = abs(ellipses(:,3)-e(3));        
        dist_r2 = abs(ellipses(:,4)-e(4));         
        if all(dist_d > opts.ellipse_detect_d_cluster | ...
               dist_r1 > opts.ellipse_detect_r1_cluster | ...
               dist_r2 > opts.ellipse_detect_r2_cluster)        
            % Store ellipse
            ellipses(end+1,:) = e; %#ok<AGROW>
        end
    end 
        
    % Four point marker detection; load stuff ----------------------------%
        
    % Load marker templates
    marker_templates = util.read_data(opts.four_point_detect_marker_templates_path);
       
    % Normalize them with mean-norm normalization since cross correlation
    % is performed
    for i = 1:4
        marker_templates.polar_patches{i} = alg.normalize_array(marker_templates.polar_patches{i}, 'mean-norm');
    end
    
    % Read marker config
    marker_config = util.read_data(opts.four_point_detect_marker_config_path);
    
    % For theta, sample 1 more and then remove it; this allows [0 2*pi)
    theta_samples = linspace(0,2*pi,marker_config.num_samples_theta+1)';
    theta_samples(end) = []; 
        
    % Get normalized radius and theta samples used for sampling polar patch
    radius_samples = linspace(marker_config.range_r_norm(1), ...
                              marker_config.range_r_norm(2), ...
                              marker_config.num_samples_radius)';
                          
    % Perform fast threshold ---------------------------------------------%
    
    % Get fast threshold template
    template_ft = vertcat(zeros(1,numel(theta_samples)), ...
                          ones(1,numel(theta_samples)), ...
                          zeros(1,numel(theta_samples)), ...
                          ones(1,numel(theta_samples)));
    
    % Sample 0.5*r, 1.5*r, 2.5*r, and 4.0*r
    %   0.5*r and 4.0*r are probably the most certain. 1.5*r and 2.5*r are
    %   less certain... maybe play with weighted cost function.
    sf_ft = [0.5 1.5 2.5 4.0];
    
    % Get interpolator
    I_array = griddedInterpolant({1:size(array,1),1:size(array,2)}, ...
                                 array, ...
                                 opts.four_point_detect_interp, ...
                                 'none');
    
    % Iterate over ellipses
    c_ft = zeros(size(ellipses,1),1);
    for i = 1:size(ellipses,1)
        % Get ellipse
        e = ellipses(i,:);
        
        % Initialize polar patch
        polar_patch = zeros(4,numel(theta_samples));   
        
        % Sample at different scale factors
        for j = 1:4            
            % Get sampling points
            e_polar_patch = e;
            e_polar_patch(3) = sf_ft(j)*(e_polar_patch(3)+0.5);
            e_polar_patch(4) = sf_ft(j)*(e_polar_patch(4)+0.5);
            p_polar_patch = alg.sample_ellipse(e_polar_patch,theta_samples);

            % Sample
            polar_patch(j,:) = I_array(p_polar_patch(:,2),p_polar_patch(:,1));
        end
        
        % Get mse between polar patch and template
        c_ft(i) = mean(mean((polar_patch - template_ft).^2));
    end
        
    % Get most powerful marker responses specified by num_cutoff and
    % mse_cutoff
    [~,idx_c_sorted] = sort(c_ft);
    idx_c_sorted = idx_c_sorted(1:min(opts.four_point_detect_num_cutoff,end));
    idx_c_sorted = idx_c_sorted(c_ft(idx_c_sorted) > opts.four_point_detect_mse_cutoff);    
    ellipses = ellipses(idx_c_sorted,:);
    
    % Do more refined matching to distinguish four markers ---------------%
            
    % Get polar patches based on ellipses
    polar_patches = cell(1,size(ellipses,1));    
                                  
    % Iterate over ellipses
    for i = 1:size(ellipses,1)          
        % Sample polar patch; get xform first
        xform = alg.ellipse2xform(ellipses(i,:));
        
        % Get normalized samples
        x = bsxfun(@times,cos(theta_samples),radius_samples'); 
        y = bsxfun(@times,sin(theta_samples),radius_samples'); 
        
        % Apply xform
        p_polar_patch = xform * vertcat(x(:)',y(:)',ones(1,numel(theta_samples)*numel(radius_samples)));
        
        % Check for out of bounds points
        if any(p_polar_patch(1,:) < 1 | p_polar_patch(1,:) > size(array,2) | ...
               p_polar_patch(2,:) < 1 | p_polar_patch(2,:) > size(array,1))
            continue
        end
            
        % Resample
        polar_patch = alg.interp_array(array, p_polar_patch(1:2,:)', marker_config.interp);
        polar_patches{i} = reshape(polar_patch,numel(theta_samples),[]);
        polar_patches{i} = alg.normalize_array(polar_patches{i},'mean-norm'); % cross correlation is performed, so do mean-norm normalization
        polar_patches{i} = polar_patches{i}(:,opts.four_point_detect_padding_radial+1: ...
                                              end-opts.four_point_detect_padding_radial); % Trim according to padding
    end
    
    % Cross correlate each polar patch with 4 templates. 
    cc_mat = -Inf(numel(polar_patches),4); % Due to radial padding, this wont strictly be between -1 and 1, but it should be close
    idx_i_mat = -1*ones(numel(polar_patches),4);
    idx_j_mat = -1*ones(numel(polar_patches),4);
    for i = 1:numel(polar_patches)
        % Make sure polar patch isn't empty, which can happen if sampling
        % points were outside of field of view.
        if isempty(polar_patches{i})
            continue
        end
                
        % Compare to four templates with circular cross correlation over
        % theta and slide over radius if padding is provided.
        for j = 1:4
            cc_buf = zeros(numel(theta_samples),2*opts.four_point_detect_padding_radial+1);
            for m = 1:2*opts.four_point_detect_padding_radial+1
                for n = 1:size(polar_patches{i},2)
                    cc_buf(:,m) = cc_buf(:,m) + ifft(fft(polar_patches{i}(:,n)).*conj(fft(marker_templates.polar_patches{j}(:,m+n-1))));
                end
            end
            
            % Get max correlation and store in cc_mat
            [idx_i_max, idx_j_max] = find(cc_buf == max(cc_buf(:)),1);
            cc_mat(i,j) = cc_buf(idx_i_max,idx_j_max);
            idx_i_mat(i,j) = idx_i_max; % Theta shift
            idx_j_mat(i,j) = idx_j_max; % Radial shift
        end
    end   
        
    % Get best matches and store four points
    patch_matches = struct('patch',cell(4,1), ...
                           'template',cell(4,1), ...
                           'ellipse',cell(4,1), ...
                           'cc_val',cell(4,1));
    p_fp_ps = zeros(4,2);
    for i = 1:4        
        % Get max value
        [idx_i_max, idx_j_max] = find(cc_mat == max(cc_mat(:)),1);
                     
        % Set coordinates
        p_fp_ps(idx_j_max,:) = [ellipses(idx_i_max,1) ellipses(idx_i_max,2)];
                       
        % Store best patch matches
        patch_matches(idx_j_max).patch = circshift(polar_patches{idx_i_max},-(idx_i_mat(idx_i_max,idx_j_max)-1));
        patch_matches(idx_j_max).template = marker_templates.polar_patches{idx_j_max}(:,idx_j_mat(idx_i_max,idx_j_max):idx_j_mat(idx_i_max,idx_j_max)+size(polar_patches{idx_i_max},2)-1);
        patch_matches(idx_j_max).ellipse = ellipses(idx_i_max);
        patch_matches(idx_j_max).cc_val = cc_mat(idx_i_max,idx_j_max);
                
        % "disable" this patch and template
        cc_mat(idx_i_max,:) = -Inf; % patch
        cc_mat(:,idx_j_max) = -Inf; % template
    end     
    
    % Set debugging output
    debug.blobs = blobs;
    debug.ellipses = ellipses;
    debug.patch_matches = patch_matches;
end
