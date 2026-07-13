classdef SealTest <symphonyui.core.descriptions.RigDescription
  properties
    holdingCommand = 0                     % Cell holding potential (mV)
    preTime = 15                    % Pulse leading duration (ms)
    stimTime = 30                   % Pulse duration (ms)
    tailTime = 15                   % Pulse trailing duration (ms)
    pulseAmplitude = 5              % Pulse amplitude (mV or pA)
  end
  
  properties (Hidden)
    statusFigure
  end
  
  methods
    
    function didSetRig(obj)
      didSetRig@admin.core.Protocol(obj);
    end
    
    function p = getPreview(obj, panel)
      p = symphonyui.builtin.previews.StimuliPreview(panel, ...
        @()createPreviewStimuli(obj));
      function s = createPreviewStimuli(obj)
        gen = symphonyui.builtin.stimuli.PulseGenerator(...
          obj.createAmpStimulus().parameters);
        s = gen.generate();
      end
    end
    
    function prepareRun(obj)
      fprintf('%s ran at %s', ...
        class(obj), ...
        datestr(clock,'\nyyyymmdd_HH:MM:SS.FFF\n\n') ...
        );
      % for indefinite protocols like seal test, we need to skip over admin
      % protocol and call the symphony protocol.
      prepareRun@symphonyui.core.Protocol(obj);
      hAmp = obj.rig.getDevice(obj.amp);
      
      if isempty(obj.statusFigure) || ~isvalid(obj.statusFigure)
        obj.statusFigure = obj.showFigure(...
          'symphonyui.builtin.figures.CustomFigure', @null);
        f = obj.statusFigure.getFigureHandle();
        set(f, 'Name', 'Status');
        layout = uix.VBox('Parent', f);
        uix.Empty('Parent', layout);
        obj.statusFigure.userData.text = uicontrol( ...
          'Parent', layout, ...
          'Style', 'text', ...
          'FontSize', 24, ...
          'HorizontalAlignment', 'center', ...
          'String', '');
        uix.Empty('Parent', layout);
        set(layout, 'Height', [-1 42 -1]);
      end
      
      if isvalid(obj.statusFigure)
        obj.statusFigure.userData.text.String = sprintf( ...
          'Running (%-d %s)...', ...
          obj.holdingCommand, ...
          hAmp.background.displayUnits ...
          );
      end
      %Force holdingCommand into amplifier background
      hAmp.background = symphonyui.core.Measurement(...
        obj.holdingCommand, ... %amplitude
        hAmp.background.displayUnits... %units
        );
    end
    
    function stim = createAmpStimulus(obj)
      hAmp = obj.rig.getDevice(obj.amp);
      try
        bgUnits = hAmp.background.displayUnits;
      catch
        bgUnits = 'mV';
      end
      %generate Stim
      gen = symphonyui.builtin.stimuli.RepeatingPulseGenerator();
      
      gen.preTime = obj.preTime;
      gen.stimTime = obj.stimTime;
      gen.tailTime = obj.tailTime;
      gen.amplitude = obj.pulseAmplitude;
      gen.mean = obj.holdingCommand;
      gen.sampleRate = obj.sampleRate;
      gen.units = bgUnits;
      
      stim = gen.generate();
    end
    
    function prepareEpoch(obj, epoch)
      % for indefinite protocols like seal test, we need to skip over admin
      % protocol and call the symphony protocol.
      prepareEpoch@symphonyui.core.Protocol(obj, epoch);
      % if oscilloscope exists and is on, send a special truncated pulse to it
      % rather that have it scroll in real time.
      hAmp = obj.rig.getDevice(obj.amp);
      if ismember('Oscilloscope',obj.rig.getDeviceNames')
        p = symphonyui.builtin.stimuli.RepeatingPulseGenerator();
        
        p.preTime = 0;
        p.stimTime = 1;
        p.tailTime = obj.preTime + obj.stimTime + obj.tailTime - 1;
        p.amplitude = 1;
        p.mean = 0;
        p.sampleRate = obj.sampleRate;
        p.units = obj.rig.getDevice(...
          'Oscilloscope'...
          ).background.displayUnits;
        
        epoch.addStimulus(obj.rig.getDevice('Oscilloscope'), ...
          p.generate());
      end
      % add amp stimulus
      epoch.addStimulus(hAmp, obj.createAmpStimulus());
    end
    
    function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < 1;
    end
    
    function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < 1;
    end
    
    function completeRun(obj)
      completeRun@admin.core.Protocol(obj);
      
      if isvalid(obj.statusFigure)
        set(obj.statusFigure.userData.text, 'String', 'Completed');
      end
    end
    
  end
  
end

