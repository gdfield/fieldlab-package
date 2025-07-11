classdef GDFGratings < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Grating leading duration (ms)
        stimTime = 8000                 % Grating duration (ms)
        tailTime = 250                  % Grating trailing duration (ms)
        waitTime = 0                    % Grating wait time before motion (ms)
        contrast = 1.0                  % Grating contrast (0-1)
        orientations = 0:30:330         % Grating orientation (deg)
        barWidths = [100,400]           % Grating half-cycle width (microns)
        temporalFrequencies = [2,4]     % Range of temporal frequencies to test.
        spatialPhase = 0.0              % Spatial phase of grating (deg)
        randomOrder = true              % Random orientation order?
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        apertureRadius = 0              % Aperture radius in microns.
        apertureClass = 'spot'          % Spot or annulus?       
        spatialClass = 'sinewave'       % Spatial type (sinewave or squarewave)
        temporalClass = 'drifting'      % Temporal type (drifting or reversing)      
        onlineAnalysis = 'extracellular'         % Type of online analysis
        numberOfAverages = uint16(1)   % Number of epochs
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
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
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

            % Generate the list of possible combinations.
            tmp_orient = obj.orientations(:) * ones(1,length(obj.barWidths)*length(obj.temporalFrequencies));
            tmp_width = obj.barWidths(:) * ones(1,length(obj.orientations)*length(obj.temporalFrequencies));
            tmp_freq = obj.temporalFrequencies(:) * ones(1,length(obj.orientations)*length(obj.barWidths));
            tmp_orient = tmp_orient(:)';
            tmp_width = tmp_width(:)';
            tmp_freq = tmp_freq(:)';

            % Calculate the number of repetitions of each annulus type.
            %numReps = ceil(double(obj.numberOfAverages) / length(tmp_freq));
            numReps = double(obj.numberOfAverages) * length(obj.orientations) * length(barWidths) * length(obj.temporalFrequencies)
            
            % Set the sequence.
            if obj.randomOrder
                
                plot_random_order = l
                
                epoch_order = randperm(length(tmp_orient));
                obj.sequence = zeros(length(tmp_orient), numReps);
                obj.sizeSequence = zeros(length(tmp_orient), numReps);
                obj.freqSequence = zeros(length(tmp_orient), numReps);
                for k = 1 : numReps
                    obj.sequence(:,k) = tmp_orient(epoch_order);
                    obj.sizeSequence(:,k) = tmp_width(epoch_order);
                    obj.freqSequence(:,k) = tmp_freq(epoch_order);
                end
            else
                obj.sequence = tmp_orient(:) * ones(1, numReps);
                obj.sizeSequence = tmp_width(:) * ones(1, numReps);
                obj.freqSequence = tmp_freq(:) * ones(1, numReps);
            end
            obj.sequence = obj.sequence(:)';
            obj.sizeSequence = obj.sizeSequence(:)';
            obj.freqSequence = obj.freqSequence(:)';
            obj.sequence = obj.sequence(1 : obj.numberOfAverages);
            obj.sizeSequence = obj.sizeSequence(1 : obj.numberOfAverages);
            obj.freqSequence = obj.freqSequence(1 : obj.numberOfAverages);
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
            
            % Set the current orientation.
            obj.orientation = obj.sequence(obj.numEpochsCompleted+1);

            % Set the temporal frequency.
            obj.temporalFrequency = obj.freqSequence(obj.numEpochsCompleted+1);
            
            % Get the bar width in pixels
            obj.barWidth = obj.sizeSequence(obj.numEpochsCompleted+1);
            obj.barWidthPix = obj.rig.getDevice('Stage').um2pix(obj.barWidth);
            epoch.addParameter('barWidth', obj.barWidth);
            
            % Get the spatial frequency.
            obj.spatialFrequency = 1/(2*obj.barWidthPix);

            % Add the spatial frequency to the epoch.
            epoch.addParameter('spatialFrequency', obj.spatialFrequency);

            % Add the temporal frequency in Hz.
            epoch.addParameter('temporalFrequency', obj.temporalFrequency);
            
            % Save out the current orientation.
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
