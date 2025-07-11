classdef GratingDSOS_ks < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Grating leading duration (ms)
        stimTime = 5000                 % Grating duration (ms)
        tailTime = 250                  % Grating trailing duration (ms)
        waitTime = 0                    % Grating wait time before motion (ms)
        contrast = 1.0                  % Grating contrast (0-1)
        orientations = [0 90]           % Grating orientation (deg)
        barWidths = [100 400]           % Grating half-cycle width (microns)
        temporalFrequencies = [2]       % Range of temporal frequencies to test.
        spatialPhase = 0.0              % Spatial phase of grating (deg)
        randomOrder = true              % Random orientation order?
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        apertureRadius = 0              % Aperture radius in microns.
        apertureClass = 'spot'          % Spot or annulus?       
        spatialClass = 'sinewave'       % Spatial type (sinewave or squarewave)
        temporalClass = 'drifting'      % Temporal type (drifting or reversing)      
        onlineAnalysis = 'extracellular'% Type of online analysis
        numReps = uint16(3)             % Number of repetitions
    end
    
    properties (Hidden)
        ampType
        apertureClassType = symphonyui.core.PropertyType('char', 'row', {'spot', 'annulus'})
        spatialClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'drifting', 'reversing'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        orientationsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        barWidthsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        temporalFrequenciesType = symphonyui.core.PropertyType('denserealdouble','matrix')
        spatialFrequency
        orientation
        phaseShift
        barWidth
        barWidthPix
        apertureRadiusPix
        sequence
        sizeSequence
        freqSequence
        temporalFrequency
        numberOfAverages = uint16(48)   % Number of epochs
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            % Calculate numberOfAverages first
            [orientGrid, widthGrid, freqGrid] = ndgrid(obj.orientations, obj.barWidths, obj.temporalFrequencies);
            numConditions = numel(orientGrid);
            obj.numberOfAverages = obj.numReps * numConditions;
            
            % Now call parent's prepareRun with correctly set numberOfAverages
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            % Rest of your prepareRun code...
            if ~obj.isMeaRig
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('manookinlab.figures.GratingDSFigure', ...
                        obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                        'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                        'orientations', obj.orientations, ...
                        'temporalFrequency', obj.temporalFrequency);
                end
            end
            
            % Convert from microns to pixels
            obj.apertureRadiusPix = obj.rig.getDevice('Stage').um2pix(obj.apertureRadius);
            obj.organizeParameters();
        end
        
        function organizeParameters(obj)
            % Generate all combinations using ndgrid
            [orientGrid, widthGrid, freqGrid] = ndgrid(obj.orientations, obj.barWidths, obj.temporalFrequencies);
            tmp_orient = orientGrid(:)';
            tmp_width = widthGrid(:)';
            tmp_freq = freqGrid(:)';
        
            % Calculate total number of epochs
            numConditions = length(tmp_orient); % Should be number of all possible combinations
            % Note: numberOfAverages already set in prepareRun
        
            % Set the sequence
            if obj.randomOrder
                % Initialize sequences
                obj.sequence = zeros(1, obj.numberOfAverages);
                obj.sizeSequence = zeros(1, obj.numberOfAverages);
                obj.freqSequence = zeros(1, obj.numberOfAverages);
                
                % Seed the random number generator with current time
                rng('shuffle');
                
                % Generate a unique random permutation for each repetition
                for rep = 1:obj.numReps
                    indices = randperm(numConditions);
                    startIdx = (rep - 1) * numConditions + 1;
                    endIdx = rep * numConditions;
                    obj.sequence(startIdx:endIdx) = tmp_orient(indices);
                    obj.sizeSequence(startIdx:endIdx) = tmp_width(indices);
                    obj.freqSequence(startIdx:endIdx) = tmp_freq(indices);
                end
            else
                % Non-random order: repeat conditions in fixed order
                obj.sequence = repmat(tmp_orient, 1, obj.numReps);
                obj.sizeSequence = repmat(tmp_width, 1, obj.numReps);
                obj.freqSequence = repmat(tmp_freq, 1, obj.numReps);
            end
        
            % Debug print
            disp('Sequence:');
            disp(obj.sequence);
            disp('Size Sequence:');
            disp(obj.sizeSequence);
            disp('Freq Sequence:');
            disp(obj.freqSequence);
        end
        
        function p = createPresentation(obj)
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create the grating.
            switch obj.spatialClass
                case 'sinewave'
                    grate = stage.builtin.stimuli.Grating('sine');
                otherwise % Square-wave grating
                    grate = stage.builtin.stimuli.Grating('square'); 
            end
            grate.orientation = obj.orientation;
            if obj.apertureRadiusPix > 0 && obj.apertureRadiusPix < max(obj.canvasSize/2) && strcmpi(obj.apertureClass, 'spot')
                grate.size = 2*obj.apertureRadiusPix*ones(1,2);
            else
                grate.size = sqrt(sum(obj.canvasSize.^2)) * ones(1,2);
            end
            grate.position = obj.canvasSize/2;
            grate.spatialFreq = 1/(2*obj.barWidthPix); %convert from bar width to spatial freq
            grate.contrast = obj.contrast;
            grate.color = 2*obj.backgroundIntensity;
            %calc to apply phase shift s.t. a contrast-reversing boundary
            %is in the center regardless of spatial frequency. Arbitrarily
            %say boundary should be positve to right and negative to left
            %crosses x axis from neg to pos every period from 0
            zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1); 
            offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
            [shiftPix, ~] = min(offsets); % min(offsets(offsets>0)); %positive shift in pixels
            phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
            obj.phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
            grate.phase = obj.phaseShift + obj.spatialPhase; %keep contrast reversing boundary in center
            
            % Add the grating.
            p.addStimulus(grate);
            
            % Make the grating visible only during the stimulus time.
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
            
            %--------------------------------------------------------------
            % Control the grating phase.
            if strcmp(obj.temporalClass, 'drifting')
                imgController = stage.builtin.controllers.PropertyController(grate, 'phase',...
                    @(state)setDriftingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            else
                imgController = stage.builtin.controllers.PropertyController(grate, 'phase',...
                    @(state)setReversingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            end
            p.addController(imgController);
            
            % Set the drifting grating.
            function phase = setDriftingGrating(obj, time)
                if time >= 0
                    phase = obj.temporalFrequency * time * 2 * pi;
                else
                    phase = 0;
                end
                
                phase = phase*180/pi + obj.phaseShift + obj.spatialPhase;
            end
            
            % Set the reversing grating
            function phase = setReversingGrating(obj, time)
                if time >= 0
                    phase = round(0.5 * sin(time * 2 * pi * obj.temporalFrequency) + 0.5) * pi;
                else
                    phase = 0;
                end
                
                phase = phase*180/pi + obj.phaseShift + obj.spatialPhase;
            end

            if obj.apertureRadius > 0
                if strcmpi(obj.apertureClass, 'spot')
                    aperture = stage.builtin.stimuli.Rectangle();
                    aperture.position = obj.canvasSize/2;
                    aperture.color = obj.backgroundIntensity;
                    aperture.size = [max(obj.canvasSize) max(obj.canvasSize)];
                    mask = stage.core.Mask.createCircularAperture(obj.apertureRadiusPix*2/max(obj.canvasSize), 1024);
                    aperture.setMask(mask);
                    p.addStimulus(aperture);
                else
                    mask = stage.builtin.stimuli.Ellipse();
                    mask.color = obj.backgroundIntensity;
                    mask.radiusX = obj.apertureRadiusPix;
                    mask.radiusY = obj.apertureRadiusPix;
                    mask.position = obj.canvasSize / 2;
                    p.addStimulus(mask);
                end
            end
            disp(['Grating: Orientation = ', num2str(grate.orientation), ', SpatialFreq = ', num2str(grate.spatialFreq)]);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Remove the Amp responses if it's an MEA rig
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
            
            % Set the current orientation
            obj.orientation = obj.sequence(obj.numEpochsCompleted + 1);
            obj.temporalFrequency = obj.freqSequence(obj.numEpochsCompleted + 1);
            obj.barWidth = obj.sizeSequence(obj.numEpochsCompleted + 1);
            obj.barWidthPix = obj.rig.getDevice('Stage').um2pix(obj.barWidth);
            
            % Debug print
            fprintf('Epoch %d: Orientation = %d, BarWidth = %d μm, BarWidthPix = %f pixels, TemporalFreq = %d\n', ...
                obj.numEpochsCompleted + 1, obj.orientation, obj.barWidth, obj.barWidthPix, obj.temporalFrequency);
            
            % Get the spatial frequency
            obj.spatialFrequency = 1 / (2 * obj.barWidthPix);
            
            % Add parameters to the epoch
            epoch.addParameter('barWidth', obj.barWidth);
            epoch.addParameter('spatialFrequency', obj.spatialFrequency);
            epoch.addParameter('temporalFrequency', obj.temporalFrequency);
            epoch.addParameter('orientation', obj.orientation);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end