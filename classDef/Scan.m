classdef Scan < handle
% Naming conventions

% % Methods
% Method names should be all lower case
% Words in an method name should be separated by an underscore
% Non-public method should begin with a single underscore
% If a method name needs to be mangled, two underscores may begin its name

% % Constants
% Constant names must be fully capitalized
% Words in a constant name should be separated by an underscore
 
% % Instance Variables
% Instance variable names should be all lower case
% Words in an instance variable name should be separated by an underscore
% Non-public instance variables should begin with a single underscore
% If an instance name needs to be mangled, two underscores may begin its name
    
% Structure of data field: [vertical_axis | horizontal_axis | angle/energy_axis | scan_axis]

    properties
        data;
        motor_positions;
        mask;    
        crop_flag = 0;
        white_field;
        dark_field;
        data_max;
        data_min;
        data_average;
        data_binned;
        data_cropped;
        data_3d;
        data_integral;
        data_meta;         
        STXMmap;
    end
    
    % - Constructor of the object -
    methods
        function scan = Scan(input_param)   
            if nargin == 1
                scan.data_meta      = input_param;                              
            end
        end
    end    
    
    % - Processing methods -
    methods
        function create_path(scan,path)
            switch scan.data_meta.beamline_id
                
                case '34idc'
                    % For 34 idc output is a list of tiff files
                    % =========================================================================
                    % --- Assemble 'master' file names
                    % =========================================================================
                    if ~exist('path')                
                        try % 34IDC option        
                           main_dir =  fullfile(scan.data_meta.pre_path_data,scan.data_meta.beamtime_id,...
                                                ['AD' scan.data_meta.beamtime_prefix '_' scan.data_meta.sample_name]);
                        catch
                           main_dir = fullfile('/asap3','petra3','gpfs','p10','2018','data', scan.data_meta.beamtime_id, 'raw'); % E.g. on Office Linux PCs            ; % E.g. on  Windows PCs        
                        end
                    else
                        main_dir = path;
                    end
                    
                    if strcmpi(scan.data_meta.sample_name(end),'_') ~= 1
                        scan.data_meta.sample_name = [scan.data_meta.sample_name '_'];
                    end

                    for jj = 1:numel(scan.data_meta.scan_number)
                        master_folder = fullfile(main_dir, [scan.data_meta.beamtime_prefix '_' ...
                                                 scan.data_meta.sample_name 'S' sprintf('%04i',scan.data_meta.scan_number(jj))]);

                        t = dir(fullfile(master_folder,'*.tif'));

                        for ii = 1:length(t)
                            scan.data_meta.scan(jj).file(ii).name        = fullfile(master_folder,t(ii).name);
                        end
                    end
                    
                case 'nanomax'
                    if nargin == 1                            
                        main_dir =  fullfile(scan.data_meta.pre_path_data, scan.data_meta.beamtime_id, 'raw', scan.data_meta.sample_name);
                    else
                        main_dir = path;
                    end
                    
                    for jj = 1:numel(scan.data_meta.scan_number)                        
                        scan.data_meta.scan(jj).file.name = fullfile(main_dir,sprintf('scan_%06i_%s.hdf5',scan.data_meta.scan_number(jj),scan.data_meta.detector_id));                        
                    end
                
            end
        end
        
        function create_mask_projection(scan)           
            for jj = 3:-1:1
                hF = figure;
                hAx = axes('Parent',hF);
                imagesc(log10(squeeze(sum(scan.data,jj))));

                hROI = drawfreehand(hAx);
                mask = createMask(hROI);                                
                mask = abs(mask-1);
                
                for ii = 1:size(scan.data,jj)      
                    if jj == 3
                        scan.data(:,:,ii) = scan.data(:,:,ii).*mask;
                    elseif jj == 2
                        scan.data(:,ii,:) = squeeze(scan.data(:,ii,:)).*mask;
                    elseif jj == 1
                        scan.data(ii,:,:) = squeeze(scan.data(ii,:,:)).*mask;
                    end
                end
                clear mask
                close;
            end                                   
        end
        
        function create_mask(scan,dim)
            function f_capturekeystroke(H,E)
                disp(E.Key);
                switch E.Key
                    case 'escape'
                        fprintf('Mask creation is broken at:\n %s\n',[scan.data_meta.sample_name ' | Scan '...
                                       num2str(scan.data_meta.scan_number(jj)) ' | Frame ' ...
                                       num2str(ii)]);                                                         
                        flag_exit       = 1;  
                    case 'space'
                        flag_next_frame = 1;
                        disp('Frame skipped!');
                    case 'control'
                        flag_control = 1;
                        disp('Frame masking!');
                end
            end
            
            if nargin==1
                dim = '3D';
            end
            switch dim
                case '3D'   
                    flag_exit       = 0;
                    hF = figure('keypressfcn',@f_capturekeystroke);
                    hAx = axes('Parent',hF);
                    disp('Masking:\n esc - abort;\n space - next frame;\n Ctrl - mask frame;\n')
                    for jj = 1:size(scan.data,4)
                        if flag_exit
                            return;
                        else                           
                            for ii = 1:size(scan.data,3)   
                                if flag_exit
                                    return;
                                else
                                    cla(hAx);
                                    flag_next_frame = 0;  
                                    flag_control    = 0;
                                    scan.mask(:,:,ii,jj) = zeros(size(scan.data(:,:,ii,jj)));
                                    while ~flag_next_frame & ~flag_exit                                                                                
                                        imagesc((scan.data(:,:,ii,jj)));
                                        axis image;
                                        colormap hot;
                                        colormap jet;
                                        title({[scan.data_meta.sample_name ' | Scan '...
                                               num2str(scan.data_meta.scan_number(jj)) ' | Frame ' ...
                                               num2str(ii)], 'Space - next frame | Ctrl - mask | Esc - exit'});
                                        if flag_exit
                                            close(hF);
                                            return;                                            
                                        else
                                            waitforbuttonpress;
                                            if flag_exit
                                                close(hF);
                                                return;
                                            else
                                                if flag_control
                                                    hROI = drawfreehand(hAx);
                                                    scan.mask(:,:,ii,jj) = scan.mask(:,:,ii,jj)+createMask(hROI);
                                                    waitforbuttonpress; 
                                                else
                                                    disp('skipped')
                                                    break;
                                                end
                                            end
                                        end

                                                                       
                                    end 
                                    scan.mask(:,:,ii,jj) = scan.mask(:,:,ii,jj)>0;
                                    disp('Mask frame recorded!');
                                end
                            end
                        end
                    end
                scan.mask = abs(scan.mask-1);
                disp('Full 3D mask recorded!'); 
                close(hF);
            end
        end
                
        function read_tif(scan)
            try
                for jj = 1:numel(scan.data_meta.scan_number)
                    % Read data from 
                    for ii = 1:length(scan.data_meta.scan(jj).file)
                        scan.data(:,:,ii,jj) = single(imread(scan.data_meta.scan(jj).file(ii).name));
                    end
                    fprintf('Loaded: %s \n',[scan.data_meta.sample_name 'S' sprintf('%04i',scan.data_meta.scan_number(jj))])
                end
            catch
                error('Can not load the data!')
            end
        end   
        
        function read_nanomax_data(scan,type) 
            if strcmp(type,'bin')
                fid = fopen([scan.data_meta.scan(1).file.name(1:end-4),'bin'],'rb');
                scan.data = fread(fid);
                fclose(fid);
                fprintf('Loaded: %d \n',kk)
                
            elseif strcmp(type,'mat')
                load([scan.data_meta.scan(1).file.name(1:end-4),'mat']);
                scan.data = single(data);       
                 fprintf('Loaded: %s \n',[scan.data_meta.scan(1).file.name(1:end-4),'mat'])
                 
            elseif strcmp(type,'hh5')
                % Extract scan information first                
                try                
                    for kk = 1:numel(scan.data_meta.scan_number)  
                        if scan.data_meta.crop_flag
                            scan.data = openmultimerlin_roi(scan.data_meta.scan(kk).file.name,...
                                                            scan.data_meta.start_row,...
                                                            scan.data_meta.end_row,...
                                [scan.data_meta.roi(1),scan.data_meta.roi(2),scan.data_meta.roi(3),scan.data_meta.roi(4),scan.data_meta.start_column,scan.data_meta.end_column]);
                        else
                            scan.data = openmultimerlin_roi(scan.data_meta.scan(kk).file.name);
                        end
                        fprintf('Loaded: %d \n',kk)
                    end
                catch
                    error('No master file!')
                end
            else
                warning('Undefined or wrong file format!')
            end
        end
        
        function read_mask(scan)
%             file_temp = fullfile(scan.data_meta.save_folder,[scan.data_meta.sample_name,'_',num2str(scan.data_meta.scan_number)],scan.data_meta.mask_name);
            try
                switch scan.data_meta.mask_path(end-2:end)
                    case 'mat'
                        load(scan.data_meta.mask_path);
                        scan.mask = single(mask);
                    case 'tif'
                        scan.mask = single(imread(scan.data_meta.mask_path));
                end
                fprintf('Mask loaded:\n %s\n',scan.data_meta.mask_path);
            catch
                warning('No mask specified!');
            end
        end
               
        function read_white_field(scan)
            try
                switch scan.data_meta.white_field_path(end-2:end)
                    case 'mat'
                        load(scan.data_meta.white_field_path);
                        scan.white_field = white_field;
                    case 'tif'
                        scan.white_field = single(imread(scan.data_meta.white_field_path));
                end
%                 scan.white_field(scan.white_field < 6000) = 1e25;
                disp('### White field loaded ###');
            catch
                warning('No white field specified!');
            end
        end
        
        function read_dark_field(scan)
            try
                switch scan.data_meta.white_field_path(end-2:end)
                    case 'mat'
                        load(scan.data_meta.dark_field_path);
                        scan.dark_field = dark_field;
                    case 'tif'
                        scan.dark_field = single(imread(scan.data_meta.dark_field_path));
                end
                disp('### Dark field loaded ###');
            catch
                warning('No dark field specified!');
            end
        end        
        
        function read_beam_current(scan)
             switch scan.data_meta.beamline_id                
                case 'nanomax'
                    scan.data_meta.nanomax.beam_current = h5read(scan.data_meta.master_file_nanomax,sprintf('/entry%d/measurement/beam_current/',scan.data_meta.scan_number));
             end
        end
        
        function correct_low_cutoff(scan)
            scan.data(scan.data<=scan.data_meta.low_cutoff) = 0;
            disp('Data was low-tresholded');
        end
        
        function correct_dark_field(scan)
            disp('### Correcting by dark-field ###');
            try
                if ~isempty(scan.dark_field) & size(scan.data(:,:,1))==size(scan.dark_field)
                    for jj = 1:size(scan.data,4) 
                        for ii = 1:size(scan.data,3) 
                            t = scan.data(:,:,ii,jj);
                            t(scan.dark_field>1) = 0;
                            scan.data(:,:,ii,jj) = t;                                
                        end
                        fprintf('Processign Scan #%d\n',jj);
                    end
                    disp('Data corrected by dark field!')
                elseif ~isempty(scan.dark_field) & size(scan.data(:,:,1))~=size(scan.dark_field)
                    error('Dark field size does not match data size!')
                elseif isempty(scan.dark_field)
                    error('No dark field!')
                end
            catch
                if ndims(scan.data) ~= 3
                    warning('The data is not 3D! Skipped. Add functionality to method!')
                else
                    error('Can not correct by dark field');
                end
            end
        end
               
        function correct_white_field(scan)
            disp('### Correcting by white-field ###');
            try
                if ~isempty(scan.white_field) & size(scan.data(:,:,1))==size(scan.white_field)                    
                    for jj = 1:size(scan.data,4) 
                        for ii = 1:size(scan.data,3) 
                            scan.data(:,:,ii,jj) = max(scan.white_field(:)).*scan.data(:,:,ii,jj)./scan.white_field; 
                            scan.data(isinf(scan.data)) = 0;
                            scan.data(isnan(scan.data)) = 0;
                        end
                        fprintf('Processing Scan #%d\n',jj);
                    end
                    disp('Data corrected by white field!')
                elseif ~isempty(scan.white_field) & size(scan.data(:,:,1))~=size(scan.white_field)
                    error('White field size does not match data size!')
                elseif isempty(scan.white_field)
                    error('No White field!')
                end
            catch
                if ndims(scan.data) ~= 3
                    warning('The data is not 3D! Skipped. Add functionality to method!')
                else
                    error('Can not correct by white field');
                end
            end
        end
        
        function correct_mask(scan)
            disp('### Masking the data ###');
            try
                if ndims(scan.mask) == 3
                    scan.data = scan.data.*scan.mask;
                    disp('3D Mask applied!');
                elseif ismatrix(scan.mask)
                    for ii = 1:size(scan.data,3)                        
                        scan.data(:,:,ii) = scan.data(:,:,ii).*scan.mask;
                    end
                    disp('2D Mask applied!');
                end
            catch
                warning('No mask specified or exists!');
            end
        end
        
        function correct_mask_nanomax(scan)
            disp('### Masking the data ###');
            try
                for ii =1:size(scan.data,3)
                    for jj =1:size(scan.data,4)
                        scan.data(:,:,ii,jj) = scan.data(:,:,ii,jj).*single(scan.mask);
                    end
                end
                disp('Mask applied!');
            catch
                warning('No mask specified or exists!');
            end
        end
        
        function crop(scan)
            show_data_average(scan,'log');
            hRect = drawrectangle;            
            disp('### Cropping the dataset ###')
            for jj = 1:size(scan.data,4)
                for ii = 1:size(scan.data,3)
                    scan.data_crop(:,:,ii,jj) = imcrop(squeeze(scan.data(:,:,ii,jj)),hRect.Position);
                end
            end
            figure; imagesc(log10(squeeze(mean(mean(scan.data_crop,4),3)))); colormap jet; axis image;
            scan.crop_flag = 1;
        end
        
        function crop_auto(scan,value)
            % Find the center of mass
            if strcmp(value,'com')
                scan.average(3);
                com = ndimCOM(scan.data_average,'auto');
                % Minimum windows in each dimension
                window = floor(min(com,size(scan.data_average)-com));
                window(1:2) = min(window(1),window(2));
                scan.data_cropped = scan.data(round(com(1)-window(1)/2+1):round(com(1)+window(1)/2),...
                                                round(com(2)-window(2)/2+1):round(com(2)+window(2)/2),:);
            elseif strcmp(value,'max')
                scan.average(3);
                [x,y] = find(scan.data_average==max(max(scan.data_average)));
                % Minimum windows in each dimension
                window = floor(min([x,y],size(scan.data_average)-[x,y]));
                window(1:2) = min(window(1),window(2));
                scan.data_cropped = scan.data(round(x-window(1)/2+1):round(x+window(1)/2),...
                                                round(y-window(2)/2+1):round(y+window(2)/2),:);
            end
        end               
        
        function correct_hot_pixel(scan,x,y,interpolate)
            disp('### Hot-pixels correction ###');
            if ~interpolate
                scan.data(x,y,:,:) = 0;
                fprintf('Hot pixel [x:%d y:%d] zeroed!\n',x,y);
            else               
                for jj = 1:size(scan.data,4)
                    for ii = 1:size(scan.data,3)
                        try
                            scan.data(y,x,ii,jj) = mean(mean(scan.data(y-1:2:y+1,x-1:2:x+1,ii,jj)));
                        catch
                            try
                                scan.data(y,x,ii,jj) = mean(mean(scan.data(y-1:2:y+1,x+1,ii,jj)));                        
                            catch
                                scan.data(y,x,ii,jj) = mean(mean(scan.data(y+1,x-1:2:x+1,ii,jj)));                        
                            end                            
                        end
                    end
                end                                
                fprintf('Hot pixel [x:%d y:%d] interpolated!\n',x,y);
            end                
        end        
        
        function average(scan,dimsAverage)
            disp('### Averaging the data ###');            
            try  
%                 clear data_average;
                scan.data_average = squeeze(mean(scan.data,dimsAverage));                                  
            catch
                disp('Data not-averaged!');
            end                
        end
        
        function flip(scan,dim)            
            if ~exist('dim')
                warning('No dimension specified: lr / ud. Skip.')
            else
                fprintf('### Flipping the data %s ###', dim);
                switch dim
                    case 'lr'
                        scan.data = fliplr(scan.data);
                    case 'ud'
                        scan.data = flipud(scan.data);
                end
            end
        end
        
        function bin2D(scan, binning_size)
            for ii = 1:size(scan.data,3)
                for jj = 1:size(scan.data,4)
                    convoluted = conv2(scan.data(:,:,ii,jj), ones(binning_size));
                    convoluted_size = size(convoluted);
                    scan.data_binned(:,:,ii,jj) = convoluted(binning_size:binning_size:convoluted_size(1), binning_size:binning_size:convoluted_size(2));
                end
            end            
        end
                
        function [COM] = ndimCOM(IN,type)    
            disp('### Calculating the center of mass ###');
            if strcmp(type,'manual')        
                imagesc(log10(IN));axis image
                h = impoly;
                hMask = createMask(h);
                IN = IN.*hMask;
            end
            C = cellfun(@(n) 1:n, num2cell(size(IN)),'uniformoutput',0);
            [C{:}] = ndgrid(C{:});
            C = cellfun(@(x) x(:), C,'uniformoutput',0);
            C = [C{:}];
            COM(:,:) = IN(:).'*C/sum(IN(:),'double');
        end        
        
        function combine(scan,input_path)
            if nargin == 1
                input_path = pwd;
            end
            % all mat files in the path will be processed
            file_list = dir([input_path,'\*.mat']);            
            for ii = 1:length(file_list)
                 load([input_path,'\',file_list(ii).name]);
                 scan.data(:,:,:,ii) = data;
            end
            % Center
            reference_object = 1;
            fprintf('### Aligning multiple-scan data with respect to element %d in array ###\n',(reference_object));            
            
            
            for jj = 1:size(scan.data,4)-1
%                 try
%                     c = convn(gpuArray(scan.data(:,:,:,reference_object)),gpuArray(scan.data(end:-1:1,end:-1:1,end:-1:1,reference_object+jj)));
%                     c = gather(c);
%                 catch
                    disp('GPU acceleration was not found or too big array, therefore wait =)');                    
                    c = convn((scan.data(:,:,:,reference_object)),(scan.data(end:-1:1,end:-1:1,end:-1:1,reference_object+jj)));
%                 end
                
                [x,y,z] = ind2sub(size(c),find(c == max(max(max(c)))));

                shift = [x-size(scan.data(:,:,:,reference_object),1),y-size(scan.data(:,:,:,reference_object),2),z-size(scan.data(:,:,:,reference_object),3)];

                scan.data(:,:,:,reference_object+jj) = circshift(scan.data(:,:,:,reference_object+jj),shift); 
                
                fprintf('Shifted Scan #%d\n', jj);
            end           
        end
        
        function normalize_exposure(scan)
            disp('### Normalizing the data by exposure time ###');
            if ~isempty(scan.data_meta.exposure)
                scan.data = scan.data./scan.data_meta.exposure;
                fprintf('Data is normalized by exposure: %.3f s\n', scan.data_meta.exposure);
                if isempty(scan.data_meta.dead_time)
                    scan.data_meta.dead_time = 0 ;
                end
                scan.data = scan.data./(1-scan.data_meta.dead_time.*scan.data);
                fprintf('Data is normalized by dead time: %.3e s\n', scan.data_meta.dead_time);                
            else
                error('Exposure time is missing. Skipping...')
            end
        end
        
        function prepare_3d(scan)
            try
                scan.data_3d = log10(scan.data)./max(max(max(log10(scan.data))));
            catch
                warning('Can not prepare 3D array, checl the method!')
            end
        end
                        
        function integrate(scan,dimsIntegrate) % [dimensions to integrate] 
            disp('### Integrating the data ###');            
            try
                scan.data_integral = squeeze(sum(scan.data,dimsIntegrate));
                fprintf('Dimensions integrated: \n %d \n',dimsIntegrate);
            catch
                disp('Data not-integrated!');
            end
        end 
        
        function maximize(scan)
            disp('### Getting max values from each frame ###');
            try
                if ndims(scan.data) == 4                
                    scan.data_max = squeeze(sum(sum(squeeze(sum(scan.data,3)),1),2));
                    disp('Data integrated sown to 3D!');
                else
                    for ii = 1:size(scan.data,3)
                        scan.data_max(ii) = squeeze(max(max(scan.data(:,:,ii))));                        
                    end
                end                
            catch
                disp('Data not-maximised!');
            end
        end
        
        function minimize(scan)
            disp('### Getting min values from each frame ###');
            try
                if ndims(scan.data) == 4                
                    scan.data_max = squeeze(sum(sum(squeeze(sum(scan.data,3)),1),2));
                    disp('Data integrated sown to 3D!');
                else
                    for ii = 1:size(scan.data,3)                        
                        m = double(scan.data(:,:,ii)>0);
                        m(m==0) = NaN;
                        scan.data_min(ii) = squeeze(nanmin(nanmin(m.*scan.data(:,:,ii))));                        
                    end
                end                
            catch
                disp('Data not-minimized!');
            end
        end
    end
    
    % Show methods
    methods  
        function show_data_max(scan)
            maximize(scan);
            figure; plot(log10(scan.data_max),'LineWidth',2,'Marker','o');
        end
        
        function show_data_min(scan)
            minimize(scan);
            figure; plot((scan.data_min),'LineWidth',2,'Marker','o');
        end
        
        function show_dark_field(scan)
            try
                figure;            
                imagesc(scan.dark_field);
                axis image;
                colormap jet;
                colorbar;
                title('Dark field');
            catch
                error('No dark field!')
            end
        end
        
        function show_white_field(scan)
            try
                figure;            
                imagesc(scan.white_field);axis image;colormap jet;colorbar
                title('White field');
            catch
                error('No white field!')
            end
        end
        
        function show_3d(scan,isoVal)                    
            if nargin == 1
                isoVal = 0.5;
            end                            
            try
                isosurface((scan.data_3d),isoVal); axis image
            catch
                prepare_3d(scan);
                isosurface((scan.data_3d),isoVal); axis image
            end
        end
        
        function show_data_scroll(scan,scale,max_val)
            if nargin == 1
                scale = 'log';
                max_val = mean(scan.data_average(:))*.5;
            end
            
            if nargin == 2                
                scan.average(3);                    
                max_val = mean(scan.data_average(:))*.5;
            end
            
            if ndims(scan.data) == 4    
                switch scale
                    case 'log'
                        handle = implay(log10(sum(scan.data,3)));
                    case 'lin'
                        handles.imHandle = imagesc(scan.data_average);            
                end            
            else
                switch scale
                    case 'log'
                        handle = implay(log10(scan.data));
                    case 'lin'
                        handle = implay(scan.data);
                end
            end
            handle.Visual.ColorMap.MapExpression = 'hot'; 
            handle.Visual.ColorMap.UserRangeMin = 0.1;
%             handle.Visual.ColorMap.UserRangeMax = max_val;
%             handle.Visual.ColorMap.UserRange = max_val;
        end                       
        
        function handles = show_data_single(scan, scale, index)
            if nargin == 1
                index = 1;
                scale = 'lin';
            elseif nargin == 2
                index = 1;
            end
            handles.figHandle = figure;
            switch scale
                case 'lin'
                    handles.imHandle = imagesc(abs(scan.data(:,:,index)));
                    handles.colorBar = colorbar;
                case 'log'
                    handles.imHandle = imagesc(log10(abs(scan.data(:,:,index))));
                    handles.colorBar = colorbar;
                    ylabel(handles.colorBar,'log');
            end
            axis image;            
            
            colormap jet;
            title([scan.data_meta.sample_name ' | Scan ' num2str(scan.data_meta.scan_number) ' | Frame ' num2str(index)]);
        end                
        
        function handles = show_data_average(scan,scale)
            if ~exist('scale')
                scale = 'lin';
            end
            
            handles.figHandle = figure;            
            
            try 
                switch scale
                    case 'log'
                        handles.imHandle = imagesc(log10(scan.data_average)); 
                        handles.colorBar = colorbar;
                        ylabel(handles.colorBar,'log');
                    case 'lin'
                        handles.imHandle = imagesc(scan.data_average);            
                end
                axis image;            

                colormap jet;
                title(['Average: ' scan.data_meta.sample_name ' | Scan ' num2str(scan.data_meta.scan_number)]);
            catch
                warning('Average data first!');
            end
        end
        
        function handles = show_data_integral(scan)             %should output an appropriate type of a plot
            handles.figHandle = figure;            
            if scan.data_integral
                try
                    handles.imHandle = plot(scan.data_meta.nanomax.gonphi, scan.data_integral,'-o');
                catch
                    handles.imHandle = plot(scan.data_integral,'-o');
                end
                ylabel('Integral intensity');
                xlabel('Scan motor position');
                title([scan.data_meta.sample_name ' | Scan ' num2str(scan.data_meta.scan_number)]);
            elseif ismatrix(scan.data_integral)
                
                % Plotting
                try
                    hVector = (-round(size(scan.data_integral,2)/2):round(size(scan.data_integral,2)/2)-1).*scan.data_meta.nanomax.step_h*1e6;
                    vVector = (round(size(scan.data_integral,1)/2):-1:-(round(size(scan.data_integral,1)/2)-1)).*scan.data_meta.nanomax.step_v*1e6;
                catch
                    hVector = 1:size(scan.data_integral,2);
                    vVector = 1:size(scan.data_integral,1);
                end
                
                try
                    switch scale
                        case 'lin'
                            handles.imHandle = imagesc(hVector,vVector,scan.data_integral);axis image;colormap bone;colorbar;axis xy
                            xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                        case 'log'
                            handles.imHandle = imagesc(hVector,vVector,log10(scan.data_integral));axis image;colormap bone;colorbar;axis xy
                            xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                    end                    
                catch
                    warning('Can not plot an integral map');
                end
                title(['Average: ' scan.data_meta.sample_name ' | Scan ' num2str(scan.data_meta.scan_number)]);
            end
        end   
        
    end
    
    % Save methods
    methods
        function save_gif(scna,user_name)
            disp('Saving GIF animation...');
            file_temp = [scna.data_meta.sample_name,'_',num2str(scna.data_meta.scan_number)];
            mkdir(fullfile(scna.data_meta.save_folder,file_temp));            
            if nargin>1
                gif_name = fullfile(scna.data_meta.save_folder,file_temp,[user_name '.gif']);
            else                
                gif_name = fullfile(scna.data_meta.save_folder,file_temp,[scna.data_meta.sample_name,'_',num2str(scna.data_meta.scan_number),'.gif']);
            end
            f1 = figure;
            for ii = 1:size(scna.data,3)                
                imagesc(log10(squeeze(scna.data(:,:,ii))));
                colormap hot; axis image; %caxis([0.1 0.8]);
                title([scna.data_meta.sample_name ' | Scan ' num2str(scna.data_meta.scan_number) ' | Frame ' num2str(ii)]);           
                GIFanimation(gif_name, f1, 0.1, size(scna.data,3), ii);
            end
            disp('Done!');
        end
        
        function save_mask(scan)
            disp('Saving data to .mat ...');
            file_temp = [scan.data_meta.sample_name,'_',num2str(scan.data_meta.scan_number)];
            mkdir(fullfile(scan.data_meta.save_folder,file_temp));
            
            mask = scan.mask;
            
            if ndims(scan.mask) == 2
                suffix = '2D';
            else
                suffix = '3D';
            end
            
            if nargin>1
                save(fullfile(scan.data_meta.save_folder,file_temp,[user_name,'_mask_',suffix,'.mat']),'mask','-v7.3');
            else                
                save(fullfile(scan.data_meta.save_folder,file_temp,[file_temp,'_mask_',suffix,'.mat']),'mask','-v7.3');            
            end
            disp('Done!');
        end
        
        function save_bin(scan,user_name)           
            disp('Saving data to .bin ...'); 
            file_temp = [scan.data_meta.sample_name,'_',num2str(scan.data_meta.scan_number)];
            mkdir(fullfile(scan.data_meta.save_folder,file_temp));
            data = scan.data;
            if nargin>1
                name = fullfile(scan.data_meta.save_folder,file_temp,[user_name,sprintf('_%d_%d_%d_',size(data,1),size(data,2),size(data,3)),'.bin']);
                fid = fopen(name,'wb');            
            else
                name = fullfile(scan.data_meta.save_folder,file_temp,[file_temp,sprintf('_%d_%d_%d_',size(data,1),size(data,2),size(data,3)),'.bin']);
                fid = fopen(name,'wb');            
            end

            fwrite(fid,data,'double');
            fclose(fid);
            fprintf('Saved: %s \n', name);
        end
        
        function save_data(scan,user_name)
            disp('Saving data to .mat ...');
            file_temp = [scan.data_meta.sample_name,'_',num2str(scan.data_meta.scan_number)];
            mkdir(fullfile(scan.data_meta.save_folder,file_temp));
                        
            if nargin>1
                save(fullfile(scan.data_meta.save_folder,file_temp,[user_name,'.mat']),'scan','-v7.3');
                fprintf('Saved to %s\n',fullfile(scan.data_meta.save_folder,file_temp,[user_name,'.mat']))
            else
                save(fullfile(scan.data_meta.save_folder,file_temp,[file_temp,'.mat']),'scan','-v7.3');
                fprintf('Saved to %s\n',fullfile(scan.data_meta.save_folder,file_temp,[file_temp,'.mat']))
            end
            
            if scan.crop_flag
                data = scan.data_crop; %#ok<*PROPLC>
            else
                data = scan.data;
            end
            
            if scan.data_meta.save_diff
                if nargin>1
                    save(fullfile(scan.data_meta.save_folder,file_temp,[user_name,'_diff.mat']),'data','-v7.3');
                else                
                    save(fullfile(scan.data_meta.save_folder,file_temp,[file_temp,'_diff.mat']),'data','-v7.3');            
                end
            end
            
            disp('Done!');                        
            
            if strcmp(scan.data_meta.save_formats,'bin')
                      
            end
            
            disp('Done!');
        end
    end
    
    % Mapping methods
    methods 
        function handles = showScanSTXMLive(scan,mode)     
            global KEY_IS_PRESSED
            KEY_IS_PRESSED = 0;
            
            if nargin == 1
                mode = 'rect';
            end

            handles.figHandle = figure;
            subplot(1,2,1); imagesc(log10(scan.data_average)); axis image; title('Integrated intensity');

            map = zeros([size(scan.data,4),size(scan.data,3)]);

            if strcmp(mode,'rect')
                h = imrect;
            else
                h = impoly;
            end
            
            while 1   
                if strcmp(mode,'rect')
                    pos = round(getPosition(h)); %[xmin ymin width height]
                else
                    mask = createMask(h);
                end

                kk = 1;
                for ii = 1:size(scan.data,4)
                    for jj = 1:size(scan.data,3)
                        if strcmp(mode,'rect')
                            map(ii,jj) = sum(sum(scan.data(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3),kk)));
                        else
                            map(ii,jj) = sum(sum(scan.data(:,:,kk).*mask));
                        end
                        kk = kk+1;                        
                    end
                end
                subplot(1,2,2); imagesc(map); axis image
%                 xlabel(scan.metaData.fastMotorName);
%                 ylabel(scan.metaData.slowMotorName);
                title('PRESS CTRL+C TO STOP!');
                drawnow;
            end           
        end   
        
        function handles = showScanCOM(scan,mode)
            if nargin == 1
                mode = 'rect';
            end

            handles.figHandle = figure;
            subplot(2,2,[1,3]); imagesc(log10(scan.data_average)); axis image; title('Integrated intensity');
            colormap jet;
            
            mapX = zeros([size(scan.data,4),size(scan.data,3)]);
            mapY = zeros([size(scan.data,4),size(scan.data,3)]);
            
            if strcmp(mode,'rect')
                h = imrect;
            elseif strcmp(mode,'poly')
                h = impoly;
            end
            
            alphaFlag = 0;
            
            if alphaFlag              
                alpha_map = scan.data_integral'./max(scan.data_integral(:));
                alpha_map(alpha_map<0.2) = 0;                              
            end
            
%             while 1 
                if strcmp(mode,'rect')
                    pos = round(getPosition(h)); %[xmin ymin width height]
                    mask = zeros(size(scan.data_average));
                    mask(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3)) = 1;
                else
                    mask = createMask(h);                    
                end
                                                
                com0 = ndimCOM(scan.data_average.*mask,'auto');     % [v,h]           
%                 com0 = [scan.data_meta.nanomax.direct_beam(2),scan.data_meta.nanomax.direct_beam(1)];     % [v,h]           

                kk = 1;
                for ii = 1:size(scan.data,4)
                    for jj = 1:size(scan.data,3)
                        
                        com = ndimCOM(scan.data(:,:,kk).*mask,'auto');
                        
                        mapX(ii,jj) = com0(2)/com(2)-1; % strain calculation
                        mapY(ii,jj) = atand((com0(1)-com(1))*scan.data_meta.nanomax.detector_pitch/scan.data_meta.nanomax.radius); % tilt calculation

                        kk = kk+1; 
                    end
                end
                
                % Plotting
                try
                    hVector = (-round(size(mapX,2)/2):round(size(mapX,2)/2)-1).*scan.data_meta.nanomax.step_h*1e6;
                    vVector = (round(size(mapX,1)/2):-1:-(round(size(mapX,1)/2)-1)).*scan.data_meta.nanomax.step_v*1e6;
                catch
                    hVector = 1:size(mapX,2);
                    vVector = 1:size(mapX,1);
                end

                subplot(2,2,2); 
                hh = imagesc(hVector,vVector,mapX); axis xy
                try
                     set(hh,'AlphaData',alpha_map);
                catch
                    warning('Åo alpha mask')
                end
                axis image; colorbar('northoutside'); 
                title('Strain');xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                
                subplot(2,2,4);                
                hh = imagesc(hVector,vVector,mapY-mean(mapY(:)));axis xy
                try
                     set(hh,'AlphaData',alpha_map);
                catch
                    warning('Åo alpha mask')
                end
                axis image; colorbar('northoutside');                
                title('Tilt, [deg]');xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                drawnow;
%             end
        end
    end        
end

