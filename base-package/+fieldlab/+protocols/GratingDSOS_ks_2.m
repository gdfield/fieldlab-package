classdef GratingDSOS_ks_2 < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Grating leading duration (ms)
        stimTime = 5000                 % Grating duration (ms)
        tailTime = 250                  % Grating trailing duration (ms)
        waitTime = 0                    % Grating wait time before motion (ms)
        contrast = 1.0                  % Grating contrast (0-1)
        orientations = [0 90]           % Grating orientation (deg)
        barWidths = [100 400]           % Grating half-cycle width (microns)
        temporalFrequencies = [2]       % Range of temporal frequencies to test
        spatialPhase = 0.0              % Spatial phase of grating (deg)
        randomOrder = true              % Whether to randomize stimuli within each repetition
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        apertureRadius = 0              % Aperture radius in microns
        apertureClass = 'spot'          % Spot or annulus?       
        spatialClass = 'sinewave'       % Sinewave or squarewave
        temporalClass = 'drifting'      % Drifting or reversing
        onlineAnalysis = 'extracellular'% Type of online analysis
        numReps = uint16(3)             % Number of repetitions for each unique stimulus
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
        repSequence
        temporalFrequency
        numberOfAverages
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            [orientGrid, widthGrid, freqGrid] = ndgrid(obj.orientations, obj.barWidths, obj.temporalFrequencies);
            numConditions = numel(orientGrid);
            obj.numberOfAverages = obj.numReps * numConditions;
            
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            if ~obj.isMeaRig
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('manookinlab.figures.GratingDSFigure', ...
                        obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                        'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                        'orientations', obj.orientations);
                end
            end
            
            obj.apertureRadiusPix = obj.rig.getDevice('Stage').um2pix(obj.apertureRadius);
            obj.organizeParameters();
        end
        
        function organizeParameters(obj)
            [orientGrid, widthGrid, freqGrid] = ndgrid(obj.orientations, obj.barWidths, obj.temporalFrequencies);
            tmp_orient = orientGrid(:)';
            tmp_width = widthGrid(:)';
            tmp_freq = freqGrid(:)';
        
            numConditions = length(tmp_orient);
        
            if obj.randomOrder
                obj.sequence = zeros(1, obj.numberOfAverages);
                obj.sizeSequence = zeros(1, obj.numberOfAverages);
                obj.freqSequence = zeros(1, obj.numberOfAverages);
                obj.repSequence = zeros(1, obj.numberOfAverages);
                
                rng('shuffle');
                
                for rep = 1:obj.numReps
                    indices = randperm(numConditions);
                    startIdx = (rep - 1) * numConditions + 1;
                    endIdx = rep * numConditions;
                    
                    obj.sequence(startIdx:endIdx) = tmp_orient(indices);
                    obj.sizeSequence(startIdx:endIdx) = tmp_width(indices);
                    obj.freqSequence(startIdx:endIdx) = tmp_freq(indices);
                    obj.repSequence(startIdx:endIdx) = rep;
                end
            else
                obj.sequence = repmat(tmp_orient, 1, obj.numReps);
                obj.sizeSequence = repmat(tmp_width, 1, obj.numReps);
                obj.freqSequence = repmat(tmp_freq, 1, obj.numReps);
                obj.repSequence = repelem(1:obj.numReps, numConditions);
            end
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            if strcmpi(obj.spatialClass, 'sinewave')
                grate = stage.builtin.stimuli.Grating('sine');
            else
                grate = stage.builtin.stimuli.Grating('square'); 
            end
            
            grate.orientation = obj.orientation;
            if obj.apertureRadiusPix > 0 && strcmpi(obj.apertureClass, 'spot')
                grate.size = [2*obj.apertureRadiusPix, 2*obj.apertureRadiusPix];
            else
                grate.size = [sqrt(sum(obj.canvasSize.^2)), sqrt(sum(obj.canvasSize.^2))];
            end
            grate.position = obj.canvasSize/2;
            grate.spatialFreq = 1 / (2 * obj.barWidthPix);
            grate.contrast = obj.contrast;
            grate.color = 2 * obj.backgroundIntensity;

            zeroCrossings = 0:(1/grate.spatialFreq):grate.size(1);
            offsets = zeroCrossings - grate.size(1)/2;
            shiftPix = min(offsets(offsets >= 0));
            phaseShift_rad = (shiftPix / (1/grate.spatialFreq)) * (2*pi);
            obj.phaseShift = rad2deg(phaseShift_rad);
            grate.phase = obj.phaseShift + obj.spatialPhase;
            
            p.addStimulus(grate);
            
            p.addController(stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3));
            
            if strcmp(obj.temporalClass, 'drifting')
                phaseController = stage.builtin.controllers.PropertyController(grate, 'phase',...
                    @(state)setDriftingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            else
                phaseController = stage.builtin.controllers.PropertyController(grate, 'phase',...
                    @(state)setReversingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            end
            p.addController(phaseController);
            
            function phase = setDriftingGrating(obj, time)
                if time >= 0
                    phase = obj.temporalFrequency * time * 360;
                else
                    phase = 0;
                end
                phase = phase + obj.phaseShift + obj.spatialPhase;
            end
            
            function phase = setReversingGrating(obj, time)
                if time >= 0
                    phase = round(0.5 * sin(time * 2 * pi * obj.temporalFrequency) + 0.5) * 180;
                else
                    phase = 0;
                end
                phase = phase + obj.phaseShift + obj.spatialPhase;
            end

            if obj.apertureRadius > 0
                if strcmpi(obj.apertureClass, 'spot')
                    aperture = stage.builtin.stimuli.Rectangle();
                    aperture.position = obj.canvasSize/2;
                    aperture.color = obj.backgroundIntensity;
                    aperture.size = max(obj.canvasSize) * [1, 1];
                    mask = stage.core.Mask.createCircularAperture(2 * obj.apertureRadiusPix / max(obj.canvasSize), 1024);
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
            
            currentEpoch = obj.numEpochsCompleted + 1;
            
            obj.orientation = obj.sequence(currentEpoch);
            obj.temporalFrequency = obj.freqSequence(currentEpoch);
            obj.barWidth = obj.sizeSequence(currentEpoch);
            obj.barWidthPix = obj.rig.getDevice('Stage').um2pix(obj.barWidth);
            
            obj.spatialFrequency = 1 / (2 * obj.barWidthPix);
            
            epoch.addParameter('orientation', obj.orientation);
            epoch.addParameter('barWidth', obj.barWidth);
            epoch.addParameter('spatialFrequency', obj.spatialFrequency);
            epoch.addParameter('temporalFrequency', obj.temporalFrequency);
            epoch.addParameter('repetition', obj.repSequence(currentEpoch));
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end