classdef SpatialNoise_ks < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Noise leading duration (ms)
        uniqueTime = 135000             % Duration of unique noise sequence (ms)
        repeatTime = 15000              % Duration of repeating sequence at end of epoch (ms)
        tailTime = 250                  % Noise trailing duration (ms)
        contrast = 1
        stixelSizes = [90,90]           % Edge length of stixel (microns)
        gridSize = 30                   % Size of underling grid
        gaussianFilter = false          % Whether to use a Gaussian filter
        filterSdStixels = 1.0           % Gaussian filter standard dev in stixels.
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        frameDwells = uint16([1,1])     % Frame dwell.
        chromaticClass = 'BY'   % Chromatic type
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20)  % Number of epochs
        repeatDivisions = 1   % Number of times to divide and repeat the repeating sequence ks 12/23
    end
    
    properties (Dependent) 
        stimTime
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        chromaticClassType = symphonyui.core.PropertyType('char','row',{'achromatic','RGB','BY','B','Y','S-iso','LM-iso'})
        stixelSizesType = symphonyui.core.PropertyType('denserealdouble','matrix')
        frameDwellsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        stixelSize
        stepsPerStixel
        numXStixels
        numYStixels
        numXChecks
        numYChecks
        seed
        numFrames
        stixelSizePix
        stixelShiftPix
        imageMatrix
        noiseStream
        positionStream
        noiseStreamRep
        positionStreamRep
        monitor_gamma
        frameDwell
        pre_frames
        unique_frames
        repeat_frames
        time_multiple
        repeat_frames_per_division % ks 12/23
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    methods
        function didSetRig(obj)
            didSetRig@manookinlab.protocols.ManookinLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            % Get the number of frames.
            obj.numFrames = floor(obj.stimTime * 1e-3 * obj.frameRate)+15;
            obj.pre_frames = round(obj.preTime * 1e-3 * 60.0);
            obj.unique_frames = round(obj.uniqueTime * 1e-3 * 60.0);
            obj.repeat_frames = round(obj.repeatTime * 1e-3 * 60.0);
            % Calculate frames per repeat division ks 12/23
            obj.repeat_frames_per_division = round(obj.repeatTime * 1e-3 * 60.0 / obj.repeatDivisions);
            obj.repeat_frames = obj.repeat_frames_per_division * obj.repeatDivisions;

            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.chromaticClass = 'achromatic';
                obj.frameDwells = uint16(ones(size(obj.frameDwells)));
            end
            
            try
                obj.time_multiple = obj.rig.getDevice('Stage').getExpectedRefreshRate() / obj.rig.getDevice('Stage').getMonitorRefreshRate();
%                 disp(obj.time_multiple)
            catch
                obj.time_multiple = 1.0;
            end
            
            
            if obj.gaussianFilter
                % Get the gamma ramps.
                [r,g,b] = obj.rig.getDevice('Stage').getMonitorGammaRamp();
                obj.monitor_gamma = [r;g;b];
                gamma_scale = 0.5/(0.5539*exp(-0.8589*obj.filterSdStixels)+0.05732);
                new_gamma = 65535*(0.5*gamma_scale*linspace(-1,1,256)+0.5);
                new_gamma(new_gamma < 0) = 0;
                new_gamma(new_gamma > 65535) = 65535;
                obj.rig.getDevice('Stage').setMonitorGammaRamp(new_gamma, new_gamma, new_gamma);
            end            
        end
        
        % Create a Gaussian filter for the stimulus.
        function h = get_gaussian_filter(obj)
%             kernel = fspecial('gaussian',[3,3],obj.filterSdStixels);
            
            p2 = (2*ceil(2*obj.filterSdStixels)+1) * ones(1,2);
            siz   = (p2-1)/2;
            std   = obj.filterSdStixels;

            [x,y] = meshgrid(-siz(2):siz(2),-siz(1):siz(1));
            arg   = -(x.*x + y.*y)/(2*std*std);

            h     = exp(arg);
            h(h<eps*max(h(:))) = 0;

            sumh = sum(h(:));
            if sumh ~= 0
                h  = h/sumh;
            end
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3 * obj.time_multiple);
            p.setBackgroundColor(obj.backgroundIntensity);
        
            obj.imageMatrix = obj.backgroundIntensity * ones(obj.numYStixels,obj.numXStixels);
            checkerboard = stage.builtin.stimuli.Image(uint8(obj.imageMatrix));
            checkerboard.position = obj.canvasSize / 2;
            checkerboard.size = [obj.numXStixels, obj.numYStixels] * obj.stixelSizePix;
        
            % Set the minifying and magnifying functions to form discrete stixels.
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            
            % Get the filter.
            if obj.gaussianFilter
                kernel = obj.get_gaussian_filter(); 
        
                filter = stage.core.Filter(kernel);
                checkerboard.setFilter(filter);
                checkerboard.setWrapModeS(GL.MIRRORED_REPEAT);
                checkerboard.setWrapModeT(GL.MIRRORED_REPEAT);
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(checkerboard);
            
            gridVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3 * 1.011);
            p.addController(gridVisible);
            
            % Calculate preFrames and stimFrames
            preF = floor(obj.preTime/1000 * 60);
        
            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)setStixelsPatternMode(obj, state.time - obj.preTime*1e-3));
            elseif ~strcmp(obj.chromaticClass,'achromatic')
                if strcmp(obj.chromaticClass,'BY')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setBYStixels(obj, state.frame - preF));
                elseif strcmp(obj.chromaticClass,'B')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setBStixels(obj, state.frame - preF));
                elseif strcmp(obj.chromaticClass,'RGB')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setRGBStixels(obj, state.frame - preF));
                else  
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setIsoStixels(obj, state.frame - preF));
                end
            else
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)setStixels(obj, state.frame - preF));
            end
            p.addController(imgController);
            
            % Position controller
            if obj.stepsPerStixel > 1
                xyController = stage.builtin.controllers.PropertyController(checkerboard, 'position',...
                    @(state)setJitter(obj, state.frame - preF));
                p.addController(xyController);
            end
            
            % Nested function for achromatic noise
            function s = setStixels(obj, frame)
                persistent M;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                        else
                            % Calculate which repeat segment we're in
                            repeat_segment = floor((frame - obj.unique_frames) / obj.repeat_frames_per_division) + 1;
                            if repeat_segment <= obj.repeatDivisions
                                M = 2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                            else
                                M = obj.backgroundIntensity * ones(obj.numYStixels,obj.numXStixels);
                            end
                        end
                        M = obj.contrast*M*obj.backgroundIntensity + obj.backgroundIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = uint8(255*M);
            end
        
            % Nested function for Blue-Yellow noise
            function s = setBYStixels(obj, frame)
                persistent M;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels,2)>0.5)-1);
                        else
                            % Calculate repeat segment
                            repeat_segment = floor((frame - obj.unique_frames) / obj.repeat_frames_per_division) + 1;
                            if repeat_segment <= obj.repeatDivisions
                                tmpM = obj.contrast*(2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels,2)>0.5)-1);
                            else
                                % Default to background if beyond repeat segments
                                M = zeros(obj.numYStixels,obj.numXStixels,3);
                                s = single(M);
                                return;
                            end
                        end
                        
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        tmpM = tmpM*obj.backgroundIntensity + obj.backgroundIntensity;
                        M(:,:,1:2) = repmat(tmpM(:,:,1),[1,1,2]);
                        M(:,:,3) = tmpM(:,:,2);
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
        
            % Nested function for RGB noise
            function s = setRGBStixels(obj, frame)
                persistent M;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels,3)>0.5)-1;
                        else
                            % Calculate repeat segment
                            repeat_segment = floor((frame - obj.unique_frames) / obj.repeat_frames_per_division) + 1;
                            if repeat_segment <= obj.repeatDivisions
                                M = 2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels,3)>0.5)-1;
                            else
                                % Default to background if beyond repeat segments
                                M = zeros(obj.numYStixels,obj.numXStixels,3) + obj.backgroundIntensity;
                                s = single(M);
                                return;
                            end
                        end
                        M = obj.contrast*M*obj.backgroundIntensity + obj.backgroundIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
        
            % Nested function for Blue noise
            function s = setBStixels(obj, frame)
                persistent M;
                w = [0.8648,-0.3985,1];
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                        else
                            % Calculate repeat segment
                            repeat_segment = floor((frame - obj.unique_frames) / obj.repeat_frames_per_division) + 1;
                            if repeat_segment <= obj.repeatDivisions
                                tmpM = obj.contrast*(2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                            else
                                % Default to background if beyond repeat segments
                                M = zeros(obj.numYStixels,obj.numXStixels,3) + obj.backgroundIntensity;
                                s = single(M);
                                return;
                            end
                        end
                        
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        M(:,:,1) = tmpM*w(1);
                        M(:,:,2) = tmpM*w(2);
                        M(:,:,3) = tmpM*w(3);
                        M = M*obj.backgroundIntensity + obj.backgroundIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
        
            % Nested function for Cone-iso noise
            function s = setIsoStixels(obj, frame)
                persistent M;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                        else
                            % Calculate repeat segment
                            repeat_segment = floor((frame - obj.unique_frames) / obj.repeat_frames_per_division) + 1;
                            if repeat_segment <= obj.repeatDivisions
                                tmpM = obj.contrast*(2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                            else
                                % Default to background if beyond repeat segments
                                M = zeros(obj.numYStixels,obj.numXStixels,3) + obj.backgroundIntensity;
                                s = single(M);
                                return;
                            end
                        end
                        
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        M(:,:,1) = tmpM*obj.colorWeights(1);
                        M(:,:,2) = tmpM*obj.colorWeights(2);
                        M(:,:,3) = tmpM*obj.colorWeights(3);
                        M = M * obj.backgroundIntensity + obj.backgroundIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
        
            % Position jitter function (unchanged)
            function p = setJitter(obj, frame)
                persistent xy;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        if frame <= obj.unique_frames
                            xy = obj.stixelShiftPix*round((obj.stepsPerStixel-1)*(obj.positionStream.rand(1,2))) ...
                                + obj.canvasSize / 2;
                        else
                            xy = obj.stixelShiftPix*round((obj.stepsPerStixel-1)*(obj.positionStreamRep.rand(1,2))) ...
                                + obj.canvasSize / 2;
                        end
                    end
                else
                    xy = obj.canvasSize / 2;
                end
                p = xy;
            end
        
            % Pattern mode function (unchanged)
            function s = setStixelsPatternMode(obj, time)
                if time > 0
                    if time <= obj.uniqueTime
                        M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                    else
                        M = 2*(obj.noiseStreamRep.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                    end
                    M = obj.contrast*M*obj.backgroundIntensity + obj.backgroundIntensity;
                else
                    M = obj.imageMatrix;
                end
                s = uint8(255*M);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Remove the Amp responses if it's an MEA rig.
            if obj.isMeaRig
                amps = obj.rig.getDevices('Amp');
                for ii = 1:numel(amps)
                    if epoch.hasResponse(amps{ii})
                        epoch.removeResponse(amps{ii});
                    end
                    if epoch.hasStimulus(amps{ii})
                        epoch.removeStimulus(amps{ii});
                    end
                end
            end
            
            if strcmpi(obj.chromaticClass, 'S-iso') || strcmpi(obj.chromaticClass, 'LM-iso')
                obj.setColorWeights();
            elseif strcmpi(obj.chromaticClass, 'Y')
                obj.colorWeights = [1;1;0];
            end
            
            % Get the current stixel size.
            obj.stixelSize = obj.stixelSizes(mod(obj.numEpochsCompleted, length(obj.stixelSizes))+1);
            obj.frameDwell = obj.frameDwells(mod(obj.numEpochsCompleted, length(obj.frameDwells))+1);
            
            % Deal with the seed.
            if obj.numEpochsCompleted == 0
                obj.seed = RandStream.shuffleSeed;
            else
                obj.seed = obj.seed + 1;
            end
            
            obj.stepsPerStixel = max(round(obj.stixelSize / obj.gridSize), 1);
            
            gridSizePix = obj.rig.getDevice('Stage').um2pix(obj.gridSize);
%             gridSizePix = obj.gridSize/(10000.0/obj.rig.getDevice('Stage').um2pix(10000.0));
            obj.stixelSizePix = gridSizePix * obj.stepsPerStixel;
            obj.stixelShiftPix = obj.stixelSizePix / obj.stepsPerStixel;
            
            % Calculate the number of X/Y checks.
            obj.numXStixels = ceil(obj.canvasSize(1)/obj.stixelSizePix) + 1;
            obj.numYStixels = ceil(obj.canvasSize(2)/obj.stixelSizePix) + 1;
            obj.numXChecks = ceil(obj.canvasSize(1)/gridSizePix);
            obj.numYChecks = ceil(obj.canvasSize(2)/gridSizePix);
            
            disp(['num checks, x: ',num2str(obj.numXChecks),'; y: ',num2str(obj.numYChecks)]);
            disp(['num stixels, x: ',num2str(obj.numXStixels),'; y: ',num2str(obj.numYStixels)]);
            
            % Seed the generator
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
            obj.positionStream = RandStream('mt19937ar', 'Seed', obj.seed);
            obj.noiseStreamRep = RandStream('mt19937ar', 'Seed', 1);
            obj.positionStreamRep = RandStream('mt19937ar', 'Seed', 1);
             
            epoch.addParameter('seed', obj.seed);
            epoch.addParameter('repeating_seed',1);
            epoch.addParameter('numXChecks', obj.numXChecks);
            epoch.addParameter('numYChecks', obj.numYChecks);
            epoch.addParameter('numFrames', obj.numFrames);
            epoch.addParameter('numXStixels', obj.numXStixels);
            epoch.addParameter('numYStixels', obj.numYStixels);
            epoch.addParameter('stixelSize', obj.gridSize*obj.stepsPerStixel);
            epoch.addParameter('stepsPerStixel', obj.stepsPerStixel);
            epoch.addParameter('frameDwell', obj.frameDwell);
            epoch.addParameter('pre_frames', obj.pre_frames);
            epoch.addParameter('unique_frames', obj.unique_frames);
            epoch.addParameter('repeat_frames', obj.repeat_frames);
            % Add the new parameters ks 12/23
            epoch.addParameter('repeatDivisions', obj.repeatDivisions);
            epoch.addParameter('repeat_frames_per_division', obj.repeat_frames_per_division);
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.uniqueTime + obj.repeatTime;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function completeRun(obj)
            completeRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            % Reset the Gamma back to the original.
            if obj.gaussianFilter
                obj.rig.getDevice('Stage').setMonitorGammaRamp(obj.monitor_gamma(1,:), obj.monitor_gamma(2,:), obj.monitor_gamma(3,:));
            end
        end
    end
end
