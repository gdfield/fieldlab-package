classdef StrictGaborRain_ks < manookinlab.protocols.ManookinLabStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 250                   % Time before stimulus (ms)
        stimTime = 10000                % Duration of the rain (ms)
        tailTime = 250                  % Time after stimulus (ms)
        
        % Grid Configuration
        stixelSize = 350                % Grid size (microns). Must be > Max Gabor Size.
        spawnChance = 0.2               % Probability of spawn per frame (0-1)
        
        % Stimulus Parameters
        contrast = 1.0                  % Contrast of the gabors (0-1)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        
        % RANDOMIZED PARAMETERS (Protocol picks from these lists)
        gaborSizes = [150 300]          % Sigma (microns). 150=Standard, 300=Large
        spatialPeriods = [60 120]       % Spatial Frequency (microns/cycle)
        temporalFreqs = [2 4]           % Drift Speed (Hz)
        orientations = 0:45:315         % 8 Directions
        lifetimeRange = [30 60]         % Duration in frames (e.g., 0.5s - 1.0s)
        
        numberOfAverages = uint16(20)   % Number of epochs
    end
    
    properties (Hidden)
        ampType
        onlineAnalysis = 'none'
        noiseSeed
        noiseStream
        
        % Safety parameters
        maxGabors = 60                  % Size of the Agent Pool (Max simultaneous patches)
        tilePadding = 10                % Safety margin (microns) inside the stixel
        
        % Internal State & History
        numXStixels
        numYStixels
        actualCanvasSize
        history                         % THE DATA LOG
        historyCount
        
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        gaborSizesType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        spatialPeriodsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        temporalFreqsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        orientationsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        lifetimeRangeType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@manookinlab.protocols.ManookinLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            if ~obj.isMeaRig
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            end
            
            stageDev = obj.rig.getDevice('Stage');
            reportedSize = stageDev.getCanvasSize();
            
            % --- CANVAS SIZE FIX ---
            % LightCrafter 4500 often reports incorrect canvas size (e.g. 640x480).
            % We override it here to ensure grid math is correct.
            if reportedSize(1) <= 640
                obj.actualCanvasSize = [1280 800]; 
            else
                obj.actualCanvasSize = reportedSize;
            end
            
            % Calculate Grid dimensions based on stixel size
            stixelSizePix = stageDev.um2pix(obj.stixelSize);
            obj.numXStixels = ceil(obj.actualCanvasSize(1)/stixelSizePix);
            obj.numYStixels = ceil(obj.actualCanvasSize(2)/stixelSizePix);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % 1. SEEDING (Reproducible Randomness)
            obj.noiseSeed = double(RandStream.shuffleSeed);
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('seed', obj.noiseSeed);
            epoch.addParameter('numXStixels', obj.numXStixels);
            epoch.addParameter('numYStixels', obj.numYStixels);
            
            % 2. INITIALIZE HISTORY LOG (Pre-allocate)
            obj.historyCount = 0;
            obj.history = struct();
            % Allocating 5000 slots (enough for ~80 seconds of rain at this density)
            obj.history.frameStart  = zeros(1, 5000);
            obj.history.gridX       = zeros(1, 5000);
            obj.history.gridY       = zeros(1, 5000);
            obj.history.size        = zeros(1, 5000);
            obj.history.orientation = zeros(1, 5000);
            obj.history.tempFreq    = zeros(1, 5000);
            obj.history.spatFreq    = zeros(1, 5000);
            % CRITICAL: Saving exact pixel positions for analysis
            obj.history.posX        = zeros(1, 5000);
            obj.history.posY        = zeros(1, 5000);
            obj.history.phaseOffset = zeros(1, 5000);
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            stageDev = obj.rig.getDevice('Stage');
            canvasSizePix = obj.actualCanvasSize;
            
            % --- PRE-CALCULATION ---
            toPix = @(microns) double(stageDev.um2pix(microns));
            stixelSizePix = toPix(obj.stixelSize);
            tilePaddingPix = toPix(obj.tilePadding);
            spatialPeriodsPix = arrayfun(@(x) toPix(x), obj.spatialPeriods);
            gaborSizesPix = arrayfun(@(x) toPix(x), obj.gaborSizes);
            
            % Random Buffer (Optimization)
            nRand = 100000; 
            randBuf = obj.noiseStream.rand(nRand, 1);
            randIdx = 1;
            
            function r = getRand()
                r = randBuf(randIdx);
                randIdx = randIdx + 1;
                if randIdx > nRand; randIdx = 1; end
            end
            
            % Grid State: 0 = Empty, 1 = Occupied
            gridState = zeros(obj.numYStixels, obj.numXStixels);
            
            % Agent Struct Definition
            emptyAgent = struct(...
                'active', false, ...
                'gridIdx', [1, 1], ...
                'birthTime', 0, ...
                'lifetimeSeconds', 0, ...
                'position', [0, 0], ...     
                'size', 0, ...              
                'spatialFreq', 0, ...       
                'temporalFreq', 0, ...
                'orientation', 0, ...
                'phaseOffset', 0, ...
                'contrast', 0 ...
                );
            agents = repmat(emptyAgent, 1, obj.maxGabors);
            
            lastUpdateTime = -1;
            frameDuration = 1.0 / obj.frameRate; 
            
            % --- AGENT POOL CREATION ---
            for i = 1:obj.maxGabors
                g = stage.builtin.stimuli.Grating('sine'); 
                g.color = 2 * obj.backgroundIntensity; 
                g.opacity = 1; 
                g.visible = false; 
                
                % Use Gaussian Envelope (512 is resolution of the mask texture)
                g.setMask(stage.core.Mask.createGaussianEnvelope(512));
                
                % Bind Controllers
                p.addController(stage.builtin.controllers.PropertyController(g, 'visible', @(state)getVisible(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'position', @(state)getPosition(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'size', @(state)getSize(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'orientation', @(state)getOrientation(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'spatialFreq', @(state)getSpatialFreq(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'phase', @(state)getPhase(state, i)));
                p.addController(stage.builtin.controllers.PropertyController(g, 'contrast', @(state)getContrast(state, i)));
                
                p.addStimulus(g);
            end
            
            % --- PHYSICS ENGINE ---
            function updateWorld(t, currentFrame)
                % 1. Clean up (Turn off agents outside stimTime)
                if t < obj.preTime*1e-3 || t > (obj.preTime + obj.stimTime)*1e-3
                     for k = 1:obj.maxGabors
                         if agents(k).active
                             gridState(agents(k).gridIdx(1), agents(k).gridIdx(2)) = 0;
                             agents(k).active = false;
                         end
                     end
                    return; 
                end
                
                % 2. Time Gate (Only run once per frame)
                if abs(t - lastUpdateTime) < (frameDuration * 0.5)
                    return;
                end
                lastUpdateTime = t;
                
                % 3. Age Existing Agents
                for k = 1:obj.maxGabors
                    if agents(k).active
                        age = t - agents(k).birthTime;
                        if age > agents(k).lifetimeSeconds
                            agents(k).active = false;
                            gridState(agents(k).gridIdx(1), agents(k).gridIdx(2)) = 0;
                        end
                    end
                end
                
                % 4. Spawn New Agents
                if getRand() < obj.spawnChance
                    [rows, cols] = find(gridState == 0);
                    if ~isempty(rows)
                        % Find a free agent slot in the pool
                        freeAgentIdx = find([agents.active] == 0, 1, 'first');
                        
                        if ~isempty(freeAgentIdx)
                            % Pick random grid location
                            choice = ceil(getRand() * length(rows));
                            r = rows(choice);
                            c = cols(choice);
                            
                            % Activate Agent
                            agents(freeAgentIdx).active = true;
                            agents(freeAgentIdx).gridIdx = [r, c];
                            gridState(r, c) = 1; % Lock grid
                            agents(freeAgentIdx).birthTime = t;
                            
                            % --- RANDOMIZE PARAMETERS ---
                            % Lifetime
                            rangeLF = obj.lifetimeRange(2) - obj.lifetimeRange(1) + 1;
                            lfFrames = floor(getRand() * rangeLF) + obj.lifetimeRange(1);
                            agents(freeAgentIdx).lifetimeSeconds = lfFrames / obj.frameRate;
                            
                            % Contrast
                            agents(freeAgentIdx).contrast = obj.contrast; 
                            
                            % Orientation
                            idxOr = floor(getRand() * length(obj.orientations)) + 1;
                            agents(freeAgentIdx).orientation = obj.orientations(idxOr);
                            
                            % Temporal Freq
                            idxTf = floor(getRand() * length(obj.temporalFreqs)) + 1;
                            agents(freeAgentIdx).temporalFreq = obj.temporalFreqs(idxTf);
                            
                            % Spatial Freq
                            idxSp = floor(getRand() * length(spatialPeriodsPix)) + 1;
                            spPix = spatialPeriodsPix(idxSp);
                            agents(freeAgentIdx).spatialFreq = 1.0 / spPix; 
                            
                            % Size (constrained by stixel)
                            idxSz = floor(getRand() * length(gaborSizesPix)) + 1;
                            desiredSize = gaborSizesPix(idxSz);
                            maxAllowed = stixelSizePix - (2 * tilePaddingPix);
                            finalSize = min(desiredSize, maxAllowed);
                            agents(freeAgentIdx).size = finalSize;
                            
                            % Position Calculation
                            % Center (0,0). xLeft is negative.
                            xLeft = -canvasSizePix(1)/2;
                            yBottom = -canvasSizePix(2)/2; 
                            
                            centerX = xLeft + (c-1)*stixelSizePix + stixelSizePix/2;
                            centerY = yBottom + (r-1)*stixelSizePix + stixelSizePix/2;
                            
                            % Jitter Logic (Random offset inside tile padding)
                            maxJitter = tilePaddingPix / 2;
                            jitterX = (getRand() * 2 - 1) * maxJitter;
                            jitterY = (getRand() * 2 - 1) * maxJitter;
                            
                            % SAVE FINAL POSITION
                            agents(freeAgentIdx).position = [centerX + jitterX, centerY + jitterY];
                            agents(freeAgentIdx).phaseOffset = getRand() * 360; 
                            
                            % --- LOGGING TO HISTORY ---
                            obj.historyCount = obj.historyCount + 1;
                            idx = obj.historyCount;
                            
                            if idx <= length(obj.history.frameStart)
                                obj.history.frameStart(idx) = currentFrame;
                                obj.history.gridX(idx)      = c; 
                                obj.history.gridY(idx)      = r; 
                                obj.history.size(idx)       = finalSize;
                                obj.history.orientation(idx)= agents(freeAgentIdx).orientation;
                                obj.history.tempFreq(idx)   = agents(freeAgentIdx).temporalFreq;
                                obj.history.spatFreq(idx)   = agents(freeAgentIdx).spatialFreq;
                                
                                % CRITICAL: Log the exact position and phase for analysis
                                obj.history.posX(idx)        = agents(freeAgentIdx).position(1);
                                obj.history.posY(idx)        = agents(freeAgentIdx).position(2);
                                obj.history.phaseOffset(idx) = agents(freeAgentIdx).phaseOffset;
                            end
                        end
                    end
                end
            end
            
            % --- CONTROLLER CALLBACKS ---
            function v = getVisible(state, idx)
                if idx == 1
                    updateWorld(state.time, state.frame); 
                end
                v = agents(idx).active;
            end
            
            function p = getPosition(~, idx)
                p = agents(idx).position;
            end
            
            function s = getSize(~, idx)
                sz = agents(idx).size;
                s = [sz, sz];
            end
            
            function o = getOrientation(~, idx)
                o = agents(idx).orientation;
            end
            
            function f = getSpatialFreq(~, idx)
                f = agents(idx).spatialFreq;
            end
            
            function ph = getPhase(state, idx)
                if agents(idx).active
                    % Phase Reset Logic:
                    % Drifting starts from t=0 relative to birth time.
                    age = state.time - agents(idx).birthTime;
                    ph = 360 * agents(idx).temporalFreq * age + agents(idx).phaseOffset;
                else
                    ph = 0;
                end
            end
            
            function c = getContrast(~, idx)
                if agents(idx).active
                    c = agents(idx).contrast;
                else
                    c = 0;
                end
            end
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % --- SAVE HISTORY TO HDF5 ---
            c = obj.historyCount;
            epoch.addParameter('rain_count', c);
            
            if c > 0
                epoch.addParameter('rain_frameStart',  obj.history.frameStart(1:c));
                epoch.addParameter('rain_gridX',       obj.history.gridX(1:c));
                epoch.addParameter('rain_gridY',       obj.history.gridY(1:c));
                epoch.addParameter('rain_size',        obj.history.size(1:c));
                epoch.addParameter('rain_orientation', obj.history.orientation(1:c));
                epoch.addParameter('rain_tempFreq',    obj.history.tempFreq(1:c));
                epoch.addParameter('rain_spatFreq',    obj.history.spatFreq(1:c));
                epoch.addParameter('rain_posX',        obj.history.posX(1:c));
                epoch.addParameter('rain_posY',        obj.history.posY(1:c));
                epoch.addParameter('rain_phaseOffset', obj.history.phaseOffset(1:c));
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end