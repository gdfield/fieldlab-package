classdef WaveformStep < symphonyui.core.descriptions.RigDescription
  % WAVEFORMSTEP A protocol that plays a fixed custom stimulus waveform
  % (loaded from a .mat file, via WaveformGenerator)

  %% Amplifier Settings
  properties
    holdPotentialOverride = false   % Check this box to override holding potential with Amp Hold (mV or pA)
    overrideCommand = 0              % Holding potential (mV or pA) if 'Hold Potential Override' is selected.
  end

  %% Stimulus source
  properties
    stimulusFile = 'D:\MCdata\waveforms\wave_repeated.mat'  % Full path to .mat file with the stimulus vector
    stimulusVariableName = 'wave_repeated'         % Name of the variable inside the .mat file
  end

  properties (Hidden)
    stimulusData    % Vector loaded from stimulusFile, cached for the whole run
  end

  %% Override methods
  methods

    function p = getPreview(obj, panel)
      p = symphonyui.builtin.previews.StimuliPreview(panel, ...
        @()obj.createAmpStimulus());  
    end

    function prepareRun(obj)
      prepareRun@admin.core.Protocol(obj);

      % Load the stimulus vector once, before the run starts, rather than
      % reloading it on every epoch.
      s = load(obj.stimulusFile, obj.stimulusVariableName);
      obj.stimulusData = s.(obj.stimulusVariableName);

      % Open figure handlers.
      hAmp = obj.rig.getDevice(obj.amp); % pointer to amplifier

      obj.showFigure( ...
        'admin.figures.Response', ...
        hAmp, ...
        'instanceId', 'Amplifier', ...
        'disableToolbar', true ...
        );

      obj.showFigure('admin.figures.MeanResponse', ...
        hAmp, ...
        'instanceId', 'Amplifier' ...
        );

      if obj.holdPotentialOverride
        bgQuant = obj.overrideCommand;
      else
        bgQuant = hAmp.background.quantity;
        obj.overrideCommand = bgQuant; % sets amp hold to current background levels
      end
      hAmp.background = symphonyui.core.Measurement( ...
        bgQuant, ...                       % amplitude
        hAmp.background.displayUnits ...   % units
        );
    end

    function prepareEpoch(obj, epoch)
      % PREPAREEPOCH Superclass method increments numEpochsPrepared
      prepareEpoch@admin.core.Protocol(obj, epoch);

      % construct this stimulus
      stim = obj.createAmpStimulus();

      % get the handle to the amplifier
      hAmp = obj.rig.getDevice(obj.amp);

      % add metadata we want to track to the epoch, so it's clear which
      % stimulus file/variable produced this epoch
      epoch.addParameter('stimulusFile', obj.stimulusFile);
      epoch.addParameter('stimulusVariableName', obj.stimulusVariableName);

      % add the stimulus and response to the amplifier
      epoch.addStimulus(hAmp, stim);
      epoch.addResponse(hAmp);
    end

    function prepareInterval(obj, interval)
      prepareInterval@admin.core.Protocol(obj, interval);

      if isscalar(obj.delayBetweenEpochs)
        delayDuration = obj.delayBetweenEpochs * 1e-3;
      else
        delayDuration = obj.delayBetweenEpochs(obj.numIntervalsPrepared) * 1e-3;
      end

      device = obj.rig.getDevice(obj.amp);
      interval.addDirectCurrentStimulus( ...
        device, ...
        device.background, ...
        delayDuration, ...
        obj.sampleRate ...
        );
    end

    function completeEpoch(obj, epoch)
      completeEpoch@admin.core.Protocol(obj, epoch);
    end

    function completeRun(obj)
      completeRun@admin.core.Protocol(obj);
    end

    function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
    end

    function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
    end

  end

  %% Helper Methods
  methods

    % Stimulus Creation
    function stim = createAmpStimulus(obj)
      % Lazily load the stimulus if createAmpStimulus is called before
      % prepareRun has populated it (e.g. from getPreview before a run
      % has been started).
      if isempty(obj.stimulusData)
        s = load(obj.stimulusFile, obj.stimulusVariableName);
        obj.stimulusData = s.(obj.stimulusVariableName);
      end

      try
        bgUnits = obj.rig.getDevice(obj.amp).background.displayUnits;
      catch
        bgUnits = 'mV';
      end

      gen = symphonyui.builtin.stimuli.WaveformGenerator();
      gen.waveshape = obj.stimulusData;
      gen.sampleRate = obj.sampleRate;
      gen.units = bgUnits;

      stim = gen.generate();
    end

  end
end
