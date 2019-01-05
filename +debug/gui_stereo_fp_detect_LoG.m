function gui_stereo_fp_detect_LoG(p_fpss, debug_stereo_fp_detect_LoG, img_cbs, calib_config, f)
    % GUI for debugging four point LoG detection

    if ~exist('f', 'var')
        f = figure();
    end
    set(f, 'Interruptible', 'off');

    % Disable KeyPressFcn until after plotting is complete
    set(f, 'KeyPressFcn', @(~, ~)drawnow);

    % Initialize parameters
    mode = 'whole';
    idx_board = 1;
    num_boards = numel(img_cbs.L);
    axes_cb_L = matlab.graphics.axis.Axes.empty();
    axes_cb_R = matlab.graphics.axis.Axes.empty();

    % Set axes parameters
    padding_height = 0.075;
    padding_width = 0.025;
    width_cb = 0.35;

    % Initialize plot
    plot_gui();

    % Set bounds
    set_bounds();

    % Set KeyPressFcn callback
    set(f, 'KeyPressFcn', @KeyPressFcn);

    function KeyPressFcn(~, eventData)
        try
            % Disable KeyPressFcn until after this is done
            set(f, 'KeyPressFcn', @(~, ~)drawnow);

            % Set idx_board
            replot = false;
            switch eventData.Key
                case 'rightarrow'
                    if idx_board < num_boards
                        idx_board = idx_board+1;
                        replot = true;
                    else
                        % Set KeyPressFcn callback
                        set(f, 'KeyPressFcn', @KeyPressFcn);
                        return
                    end
                case 'leftarrow'
                    if idx_board > 1
                        idx_board = idx_board-1;
                        replot = true;
                    else
                        % Set KeyPressFcn callback
                        set(f, 'KeyPressFcn', @KeyPressFcn);
                        return
                    end
                case 'escape'
                    mode = 'whole';
                case '1'
                    if strcmp(mode, '1')
                        mode = 'whole';
                    else
                        mode = '1';
                    end
                case '2'
                    if strcmp(mode, '2')
                        mode = 'whole';
                    else
                        mode = '2';
                    end
                case '3'
                    if strcmp(mode, '3')
                        mode = 'whole';
                    else
                        mode = '3';
                    end
                case '4'
                    if strcmp(mode, '4')
                        mode = 'whole';
                    else
                        mode = '4';
                    end
                case 'w'
                    if strcmp(mode, 'worst')
                        mode = 'whole';
                    else
                        mode = 'worst';
                    end
                otherwise
                    % Set KeyPressFcn callback
                    set(f, 'KeyPressFcn', @KeyPressFcn);
                    return
            end

            % Replot
            if replot
                plot_gui();
            end

            % Set bounds
            set_bounds();

            % Set KeyPressFcn callback
            set(f, 'KeyPressFcn', @KeyPressFcn);
        catch e
            if ishandle(f)
                rethrow(e);
            end
        end
    end

    function plot_gui()
        try
            % Clear figure and replot everything for simplicity
            clf(f);

            % Set axes
            height_patch = (1-5*padding_height)/4;
            width_patch = (1-2*width_cb-5*padding_width)/2;

            pos_cb_L = [2*padding_width+width_patch padding_height width_cb 1-2*padding_height];
            axes_cb_L = axes('Position', pos_cb_L, 'Parent', f);
            pos_cb_R = [pos_cb_L(1)+pos_cb_L(3)+padding_width pos_cb_L(2:4)];
            axes_cb_R = axes('Position', pos_cb_R, 'Parent', f);

            axes_patches_L = matlab.graphics.axis.Axes.empty();
            axes_patches_R = matlab.graphics.axis.Axes.empty();
            for i = 1:4
                pos_patch_L = [padding_width ...
                               padding_height+(4-i)*(height_patch+padding_height)  ...
                               width_patch ...
                               height_patch];
                axes_patches_L(i) = axes('Position', pos_patch_L, 'Parent', f);

                pos_patch_R = [pos_cb_R(1)+pos_cb_R(3)+padding_width ...
                               padding_height+(4-i)*(height_patch+padding_height)  ...
                               width_patch ...
                               height_patch];
                axes_patches_R(i) = axes('Position', pos_patch_R, 'Parent', f);
            end

            % Plot debugging info
            debug.plot_debug_single_fp_detect_LoG(p_fpss.L{idx_board}, ...
                                                  debug_stereo_fp_detect_LoG.L(idx_board), ...
                                                  img_cbs.L(idx_board), ...
                                                  calib_config, ...
                                                  axes_cb_L);
            title(axes_cb_L, 'Blobs, ellipses, and four points (L)', 'FontSize', 10);
            xlabel(axes_cb_L, ['Path: ' img_cbs.L(idx_board).get_path()], ...
                   'FontSize', 8, 'Interpreter', 'none');

            debug.plot_debug_single_fp_detect_LoG(p_fpss.R{idx_board}, ...
                                                  debug_stereo_fp_detect_LoG.R(idx_board), ...
                                                  img_cbs.R(idx_board), ...
                                                  calib_config, ...
                                                  axes_cb_R);
            title(axes_cb_R, 'Blobs, ellipses, and four points (R)', 'FontSize', 10);
            xlabel(axes_cb_R, ['Path: ' img_cbs.R(idx_board).get_path()], ...
                   'FontSize', 8, 'Interpreter', 'none');

            % Plot patch matches
            for i = 1:4
                debug.plot_patch_match(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(i), ...
                                       i, ...
                                       axes_patches_L(i));
            end
            for i = 1:4
                debug.plot_patch_match(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(i), ...
                                       i, ...
                                       axes_patches_R(i));
            end
        catch e
            if ishandle(f)
                rethrow(e);
            end
        end
    end

    function set_bounds()
        try
            % Set name
            set(f, 'Name', ['Board: ' num2str(idx_board) ' of ' num2str(num_boards) '; mode: ' mode '; (NOTE: press left, right, "1", "2", "3", "4", "w", and "esc" key arrows to toggle)']);

            % Set bounding box
            switch mode
                case 'whole'
                    bb_L = bb_img(img_cbs.L(idx_board), calib_config);
                    bb_R = bb_img(img_cbs.R(idx_board), calib_config);
                case '1'
                    bb_L = bb_ellipse(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(1).ellipse);
                    bb_R = bb_ellipse(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(1).ellipse);
                case '2'
                    bb_L = bb_ellipse(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(2).ellipse);
                    bb_R = bb_ellipse(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(2).ellipse);
                case '3'
                    bb_L = bb_ellipse(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(3).ellipse);
                    bb_R = bb_ellipse(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(3).ellipse);
                case '4'
                    bb_L = bb_ellipse(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(4).ellipse);
                    bb_R = bb_ellipse(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(4).ellipse);
                case 'worst'
                    % Get the worst patch
                    [~, idx_L] = min([debug_stereo_fp_detect_LoG.L(idx_board).patch_matches.val_cc]);
                    bb_L = bb_ellipse(debug_stereo_fp_detect_LoG.L(idx_board).patch_matches(idx_L).ellipse);
                    [~, idx_R] = min([debug_stereo_fp_detect_LoG.R(idx_board).patch_matches.val_cc]);
                    bb_R = bb_ellipse(debug_stereo_fp_detect_LoG.R(idx_board).patch_matches(idx_R).ellipse);
            end

            set(axes_cb_L, 'Xlim', bb_L(:, 1), 'Ylim', bb_L(:, 2));
            set(axes_cb_R, 'Xlim', bb_R(:, 1), 'Ylim', bb_R(:, 2));
        catch e
            if ishandle(f)
                rethrow(e);
            end
        end
    end
end

function bb = bb_img(img_cb, calib_config)
    % Get size of image
    height_img = img_cb.get_height();
    width_img = img_cb.get_width();

    % Get scale factor
    if isnan(calib_config.fp_detect_array_min_size)
        sf = 1;
    else
        sf = calib_config.fp_detect_array_min_size/min([height_img width_img]);
    end

    % Set bounding box
    bb = [0.5 0.5; ...
          width_img*sf+0.5 height_img*sf+0.5];
end

function bb = bb_ellipse(e)
    % Apply scale factor to ellipse
    sf = 10;
    e(3:4) = sf*e(3:4);

    % Get bounding box
    bb = alg.bb_ellipse(e);

    % Get height and width
    h = bb(2, 2) - bb(1, 2);
    w = bb(2, 1) - bb(1, 1);

    % Set bounding box to max size to make it square
    max_size = max(h, w);
    bb = [e(1)-max_size/2 e(2)-max_size/2;
          e(1)+max_size/2 e(2)+max_size/2];
end
