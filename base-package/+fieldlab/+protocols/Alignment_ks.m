classdef Alignment_ks < manookinlab.protocols.ManookinLabStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 250                   % Time before stimulus (ms)
        stimTime = 10000                % How long to hold the alignment pattern (ms)
        tailTime = 250                  % Time after stimulus (ms)
        
        intensity = 1.0                 % Intensity of the white squares (0-1)
        numberOfAverages = uint16(1)    % Number of epochs
    end
    
    properties (Hidden)
        onlineAnalysis = 'none'
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    end
    
    methods
        
        function didSetRig(obj)
            % FIX: Call the RiekeLab base directly, matching GratingDSOS.m
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
           
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            % Set background to Black (0) to make the white pop
            p.setBackgroundColor(0.0); 
            
            % --- DEFINE PATTERN ---
            % 2x2 Matrix matching your image:
            % [White  Black]
            % [Black  White]
            checkerMatrix = uint8(255 * obj.intensity * [1 0; 0 1]);
            
            % Create the Image Stimulus
            checkerboard = stage.builtin.stimuli.Image(checkerMatrix);
            
            % SCALE IT
            % Stretch the 2x2 pixels to cover the entire canvas exactly,
            % but shift left by half the photodiode bar width (read from FrameTracker if available).
            checkerboard.size = obj.canvasSize;

            % Try to read the FrameTracker width; if that fails, fall back to 50 px.
            BW_default = 50;
            BW = BW_default;
            try
                % Instantiate a temporary FrameTracker to read its size property.
                % (If your Stage API exposes a static default you could use that instead.)
                ft = stage.builtin.stimuli.FrameTracker();
                if isprop(ft, 'size') && numel(ft.size) >= 1
                    BW = double(ft.size(1));
                end
                % If the object needs explicit deletion/cleanup in your setup, do it here.
                % (Most Stage stimulus objects are GC'd; adjust if your rig requires cleanup.)
            catch
                BW = BW_default;
            end

            % Move center left by half the photodiode bar width so the pattern centers in usable area.
            checkerboard.position = [ obj.canvasSize(1)/2 - BW/2, obj.canvasSize(2)/2 ];

            
            % SHARPEN IT
            % GL.NEAREST ensures strict, sharp edges (no blurring)
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            
            % Add to presentation
            p.addStimulus(checkerboard);
            
            % Control Visibility (Show only during stimTime)
            checkerboardVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(checkerboardVisible);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            % Save the canvas size just for records
            epoch.addParameter('canvasSize', obj.canvasSize);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end