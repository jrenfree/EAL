function varargout = EAL(varargin)
% EAL MATLAB code for EAL.fig
%      EAL, by itself, creates a new EAL or raises the existing
%      singleton*.
%
%      H = EAL returns the handle to a new EAL or the handle to
%      the existing singleton*.
%
%      EAL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EAL.M with the given input arguments.
%
%      EAL('Property','Value',...) creates a new EAL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before EAL_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to EAL_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help EAL

% Last Modified by GUIDE v2.5 12-Nov-2021 15:17:28

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @EAL_OpeningFcn, ...
    'gui_OutputFcn',  @EAL_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end


function EAL_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to EAL (see VARARGIN)

% Choose default command line output for EAL
handles.output = hObject;

WarnWave = [sin(1:.6:400), sin(1:.7:400), sin(1:.4:400)];
handles.Audio = audioplayer(WarnWave, 22050);

% Get filter coefficients used for smoothing out Sv and Pr data for bottom
% detection
[handles.B, handles.A] = butter(2, .05);    % Lowpass filter coefficients

%% Set figure axes properties

% Remove the axis tick marks
set(handles.axesDepth, 'XTick', [], 'YTick', []);
set(handles.axesSlope, 'XTick', [], 'YTick', []);
set(handles.axesDZH, 'XTick', [], 'YTick', []);
set(handles.axesRoughness, 'XTick', [], 'YTick', []);

% Create y-axis labels
ylabel(handles.axesDepth, 'Depth')
ylabel(handles.axesSlope, 'Slope')
ylabel(handles.axesDZH, 'h_{ADZ}')
ylabel(handles.axesRoughness, 'Roughness')

% Update handles structure
guidata(hObject, handles);


function varargout = EAL_OutputFcn(~, ~, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function startButton_Callback(hObject, ~, handles)
% hObject    handle to startButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of startButton

warning on verbose
warning('error', 'instrument:fread:unsuccessfulRead'); %#ok<*CTPCT>
warning('error', 'instrument:fscanf:unsuccessfulRead');

if get(hObject, 'Value')
    
    %% Read settings values
    handles = readSettings(handles);
    
    %% Create the various timer objects

    % Timer for receiving subscription data
    handles.subcriptionTimer = timer('ExecutionMode', 'fixedSpacing', ...
        'Period', 0.1, ...
        'BusyMode', 'drop', ...
        'Name', 'Receive data timer', ...
        'TimerFcn', @(obj, eventdata) getData(handles.output));

    % Timer for manual ping interval
    handles.setPITimer = timer('ExecutionMode', 'singleShot', ...
        'TimerFcn', @(obj, eventdata) stopManualPI(handles.output), ...
        'Name', 'Manual Ping Interval Timer', ...
        'StartDelay', str2double(handles.settings.ManPingTime)*60);

    %% Initialize variables on each Start button press
    handles.currTime = NaN;             % Holds current ping time
    handles.firstPing = 1;              % Flag to signify EAL starting
    handles.firstPingCount = 0;         % Init # of starting pings missed
    handles.emittingDeepPing = 0;       % Flag for deep ping txmission
    handles.restartCount = 0;           % Init # of restarts
    handles.currentlyRunning = 0;       % Tells if getData() is running

    % Initialize plotting variables
    handles.lastDepths = nan(100,1);
    handles.lastSlopes = nan(100,1);
    handles.lastDZHs = nan(100,1);
    handles.lastRoughnesses = nan(100,1);
    
    %% Change GUI properties
    
    set(handles.restartTest, 'String', '');     % Clear restart status
    
    % Disable Software selection
    set(handles.softwarePulldown, 'Enable', 'off');
    
    % Disable false bottom file selection and load button while running
    set(handles.bathyFile, 'Enable', 'off');
    set(handles.bathyFileBrowse, 'Enable', 'off');
    set(handles.loadBathy, 'Enable', 'off');
    
    set(handles.setManualPI, 'Enable', 'on');   % Enable Set Ping Interval
    
    % If bathymetry estimator doesn't exist, then disable all false
    % bottom removal inputs.
    if ~isfield(handles, 'estFunc')
        set(handles.bathyLoadStatus, 'String', 'No bathymetry data loaded!');
        set(handles.bathyLoadStatus, 'Enable', 'off');
    end
    
    % Change Start button and disable inputs
    set(handles.startButton, 'BackgroundColor', 'r')	% Make button red
    set(handles.startButton, 'String', 'Stop')          % Change to Stop
        
    % Disable K-Sync inputs while operating
    set(handles.checkboxKSync, 'Enable', 'Off')
    
    % Disable ME70 options while operating
    set(handles.checkboxME70, 'Enable', 'Off')
    set(handles.ME70IPAddress, 'Enable', 'Off')
            
    % Make all output parameters blank
    set(handles.Depth, 'String', '')
    set(handles.pInterval, 'String', '')
    set(handles.lRange, 'String', '')
    
    % Update GUI display
    drawnow nocallbacks
%     drawnow expose update
    
    %% Try connecting to ER60/EK80
    try
        handles = connect2ER60(handles);
    catch ME
        set(handles.restartTest, 'String', ME.message);
        enableInputs(handles);
        return
    end
    
    %% If using K-Sync, create udp object for sending depth outputs
    if get(handles.checkboxKSync, 'Value')
        handles.KSyncDepth = udp(handles.settings.KSyncIP, ...
            str2double(handles.settings.KSyncUDPPort));
    end
    
    %% If External Depth sensor info provided, create tcpip object
    
    % If External Depth sensor parameters are defined in the Settings.txt
    % file, create a TCP/IP object
    if ~isempty(handles.settings.ExtDepthIP)
        handles.ExtDepth = tcpip(handles.settings.ExtDepthIP, 2006);
    end
    
    %% Connect to ME70 if syncing with ME70
    
    if get(handles.checkboxME70, 'Value')
        try
            
            % Get connection parameters
            ME70RemoteIp = get(handles.ME70IPAddress, 'String');    % IP address
            handles.ME70RequestID = 1;  % Init. ER60 request ID

            % Prepare and open socket connection to server.
            handles.ME70 = udp(ME70RemoteIp, ...
                str2double(handles.settings.ME70RemotePort), ...
                'ByteOrder', 'littleEndian', ...
                'DatagramTerminateMode','off');
            fopen(handles.ME70);

            % Send request server info.
            fwrite(handles.ME70, ['RSI' char(0)], 'char');

            % Get remote commandport which should be used to set up subscriptions and
            % continuously receive and respond alive messages for this connection.
            fscanf(handles.ME70,'%c',4);                 % Read header
            fscanf(handles.ME70,'%c',64);                % Application Type
            fscanf(handles.ME70,'%c',64);                % Application name
            fscanf(handles.ME70,'%c',128);               % Application description
            fread(handles.ME70,1,'int32');               % Application ID
            commandPort = fread(handles.ME70,1,'int32');	% Command Port
            fread(handles.ME70,1,'int32');               % Mode
            fscanf(handles.ME70,'%c',64);                % Host name

            % Close initial connection and open a new between our local conport
            % and the commandport provided by the ME70 server.
            fclose(handles.ME70);
            handles.ME70 = udp(ME70RemoteIp, commandPort, 'LocalPort', ...
                str2double(handles.settings.ME70ConPort), ...
                'ByteOrder', 'littleEndian', ...
                'DatagramTerminateMode', 'off', 'InputBufferSize', 1e4);
            fopen(handles.ME70);

            % Try to connect with a user and password which must be defined in
            % server ME70 application (Users and Passwords dialogue).
            fwrite(handles.ME70, ['CON' char(0) 'Name:' ...
                handles.settings.ME70Name ';Password:' ...
                handles.settings.ME70Password char(0)], 'char');

            % Receive response
            header = fscanf(handles.ME70,'%c',4);
            if strcmp(header, ['RES' char(0)])
                % Received request response
                fscanf(handles.ME70,'%c',4);
                fscanf(handles.ME70,'%c',22);
                response = fscanf(handles.ME70,'%c',1400);
            else
                error('Unknown response');
            end

            % Get CLIENTID
            handles.ME70CLIENTID = regexp(response, 'ClientID:(\d+),', 'tokens');
            handles.ME70CLIENTID = handles.ME70CLIENTID{:}{:};

            % Initialiaze client sequence number
            handles.ME70CLIENTSEQNO = 1;

            % Send an alive message every second using the sendalivemessage
            % callback function
            handles.ME70timerobj = timer('ExecutionMode', 'fixedRate', ...
                'Period', 1.0, 'Name', 'Alive timer');
            handles.ME70timerobj.TimerFcn = {@sendalivemessagesME70, handles.output};
            guidata(handles.output, handles);   % Save handles structure
            start(handles.ME70timerobj)         % Start "alive" timer
        catch ME
            disp(ME.message)
            set(handles.restartTest, 'String', 'Could not connect to ME70');
            handles = closeME70(handles);
        end
    end
    
    %% Create file for storing noise floor measurements
    
    % If Noise Measurement directory doesn't exist, create it
    if ~isfolder(fullfile(pwd, 'Noise Measurements'))
        mkdir(fullfile(pwd, 'Noise Measurements'))
    end
    
    % Create noise file
    handles.noiseFile = fopen(fullfile(pwd, 'Noise Measurements', ...
        sprintf('passiveNoise_D%s.txt', datestr(now, 30))), 'w');

    % Append header to file
    str = '';
    for i = 1:length(handles.freqs)
        str = sprintf('%s,%dkHz(dB)', str, handles.freqs(i)/1e3);
    end
    fprintf(handles.noiseFile, 'Date,Time%s\n', str);
                                        
    %% Initialize plotting variables for rolling calculations
    handles.rollingX = cell(length(handles.freqs), 3);
    handles.rollingY = cell(length(handles.freqs), 3);
    handles.rollingZ = cell(length(handles.freqs), 3);
        
    %% Change display range
    
    % Set the logging range to the ranges defined in Settings.txt
    handles.normRange = nan(length(handles.freqs), 1);
    for i = 1:length(handles.freqs)
        handles.normRange(i) = str2double(eval(sprintf('handles.settings.MaxLogRange%d', handles.freqs(i)/1e3)));
    end
        
    % Set the variable that will hold the current logging range
    handles.currRange = handles.normRange;

    % Put that range in the GUI
    set(handles.lRange, 'String', 'NA')

    % Initialize the first detection window using the full logging range.
    % Because there can be multiple logging ranges, use the maximum range
    % for the window.
    handles.RangeWindow = [0; max(handles.normRange)];
    
    % Change echogram display range
    for i = 1:length(handles.freqs)
        
        % If ER60
        if get(handles.softwarePulldown, 'Value') == 1
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' int2str(max(handles.normRange)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        
        % If EK80
        else
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' int2str(handles.normRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        end
        handles = sendrequest(handles, rString1);
        handles = sendrequest(handles, rString2);
    end
        
    %% Get ER60 parameters
    
    % Get sound speed for calculations
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{1} '/SoundVelocity</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    handles.c = str2double(readbetween('<value dt="5">','</value>',response));   % in ms
        
    % Get frequency dependent parameters that will be used for processing
    for i = 1:length(handles.freqs)
                
        % Alongship sensitivity (degrees)
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/AngleSensitivityAlongship</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.AlongshipAngleSensitivity(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % Athwartship sensitivity (degrees)
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/AngleSensitivityAthwartship</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.AthwartshipAngleSensitivity(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % Pulse length
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/PulseLength</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.tau(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % Absorption
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/AbsorptionCoefficient</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.alpha(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % Transmit Power
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/TransmitPower</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.Pt(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % On-axis Gain
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/Gain</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.G0(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % Equivalent Two-Way Beam Angle
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/EquivalentBeamAngle</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.psi(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
        
        % S_A Correction
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/SaCorrection</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        handles.Sa_corr(i) = ...
            str2double(readbetween('<value dt="5">','</value>',response));
    end
    
    %% Update ME70 trigger delay if need be
    if get(handles.checkboxME70, 'Value')
        try
            trigDelay = 1e3 * round(100 * handles.normRange * 2/handles.c)/100;    % In ms
            rString = ['<request><clientInfo><cid>' handles.ME70CLIENTID '</cid><rid>' int2str(handles.ME70RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/SyncDelay</paramName><paramValue>' int2str(trigDelay) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
            handles = sendrequestME70(handles, rString);
        catch ME
            disp(ME.message)
            set(handles.restartTest, 'String', 'Could not connect to ME70');
            handles = closeME70(handles);
        end
    end
    
    %% Store ER60 settings
    
    % Calculate ping interval based on logging range
    procTime = str2double(handles.settings.ProcBuf);
    handles.normRate = round(100*(procTime + (max(handles.normRange) * 2/handles.c)))/100;

    % Put those values in the GUI
    set(handles.pInterval, 'String', num2str(handles.normRate))
    set(handles.manualPI, 'String', num2str(handles.normRate))
        
    % See if ER60 was recording
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>SounderStorageManager/SaveRawData</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    handles.isRec = str2double(readbetween('<value dt="3">','</value>',response));

    %% Collect passive noise measurements, if wanted
    
    % Make passive noise measurements if checkbox is selected
    if get(handles.checkboxNoise, 'Value')
        
        % If noise timer exists, check to see if it's time for a new
        % measurements
        if isfield(handles, 'noiseTimer')
            
            % If time for a new measurements, do it
            if toc(handles.noiseTimer) > 60*str2double(handles.settings.PassiveInt)
                handles = collectNoise(handles);
                
            % Otherwise, display when the next measurement occurs
            else
                fprintf('Next noise measurements in %.0f seconds\n', 60*str2double(handles.settings.PassiveInt) - toc(handles.noiseTimer))
            end
            
        % If the timer doesn't exist, then collect noise data
        else
            handles = collectNoise(handles);
        end
        
    % If user doesn't wish to collect noise measurements, set to NaN
    else
        handles.noiseFloor = nan(1, length(handles.freqs));
    end
            
    %% Subscribe to data for all ER60 frequencies
    try
        handles = subscribe2ER60(handles);
    catch ME
        set(handles.restartTest, 'String', ME.message);
        enableInputs(handles);
        return
    end
                            
    %% Create plots
    handles.h(1) = plot(handles.axesDepth, handles.lastDepths, 'LineWidth', 3);
    set(handles.axesDepth, 'YDir', 'reverse', 'XGrid', 'on', 'YGrid', 'on', 'XTickLabel', '')
    ylabel(handles.axesDepth, 'Depth')
    
    handles.h(2) = plot(handles.axesSlope, handles.lastSlopes, 'LineWidth', 3);
    set(handles.axesSlope, 'XGrid', 'on', 'YGrid', 'on', 'XTickLabel', '')
    ylabel(handles.axesSlope, 'Slope')
    
    handles.h(3) = plot(handles.axesDZH, handles.lastDZHs, 'LineWidth', 3);
    set(handles.axesDZH, 'XGrid', 'on', 'YGrid', 'on', 'XTickLabel', '')
    ylabel(handles.axesDZH, 'h_{ADZ}')
    
    handles.h(4) = plot(handles.axesRoughness, handles.lastRoughnesses, 'LineWidth', 3);
    set(handles.axesRoughness, 'XGrid', 'on', 'YGrid', 'on')
    ylabel(handles.axesRoughness, 'Roughness')
                
    %% Update handles and start receiving data
    
    % The handles structure must be updated first so that when the
    % subscription timer is started, it is accessing the most up-to-date
    % version of handles.
    guidata(handles.output, handles)	% Update GUI handles structure
    start(handles.subcriptionTimer);           % Start reading ER60 udp packets 
end


function enableInputs(handles)

%% Change Stop button
set(handles.startButton, 'Value', 0)
set(handles.startButton, 'BackgroundColor', 'g')
set(handles.startButton, 'String', 'Start')

% Disable Software selection
set(handles.softwarePulldown, 'Enable', 'on');

% Enable K-Sync inputs while operating
set(handles.checkboxKSync, 'Enable', 'On')

% Enable ME70 inputs if checkbox is checked
set(handles.checkboxME70, 'Enable', 'On')
if get(handles.checkboxME70, 'Value')
    set(handles.ME70IPAddress, 'Enable', 'On');
end

% Disable Set Ping Interval input and stop timer
set(handles.setManualPI, 'Value', 0)
set(handles.setManualPI, 'Enable', 'off')
set(handles.manualPI, 'Enable', 'off')

% Enable false bottom inputs if selected
set(handles.fixFB, 'Enable', 'on');
if get(handles.fixFB, 'Value')
    set(handles.bathyFile, 'Enable', 'on');
    set(handles.bathyFileBrowse, 'Enable', 'on');
    set(handles.loadBathy, 'Enable', 'on');
    set(handles.bathyLoadStatus, 'Enable', 'inactive');
end


function getData(obj)
% CHANGE ER60 PARAMETERS BASED ON OBSERVED BOTTOM DEPTH
%   This function is periodically called by a timer object.  The function
%   begins reading the UDP buffer to collect the most recent ping data
%   returned by the ER60.  When all the data for the most recent ping has
%   been collected, a bottom detection is then performed.  The ER60
%   settings are then updated according to the bottom detection.

handles = guidata(obj);      % Get latest handles structure

% Encase in try/catch statement in case an error occurs.
try

    % If getData() is already currently running, then exit callback
    if handles.currentlyRunning == 1
        return
        
    % Otherwise, update variable which signals it is running and update
    % handles structure. Thus, if getData() is called while it is
    % currently running (i.e. event queue is flushed), it will ignore that
    % callback.
    else
        handles.currentlyRunning = 1;       % Set flag to 1
        guidata(handles.output, handles);   % Update handles structure
    end    

    % Issue full drawnow command to flush event queue and process any
    % figure changes
    drawnow

    % Get data if the start button is still pressed.  Otherwise, stop
    % subscription and GUI.
    if get(handles.startButton, 'Value')

        % Send alive messages to ER60 and EK80 objects
        handles = sendAliveMessage(handles);

        % If emitting deep ping, then wait until 5 seconds is up to prevent
        % false bottoms from being detected as the actual bottom
        if handles.emittingDeepPing
             while toc(handles.deepPingTimer) < 5 
                 
                % Send alive messages to ER60 and EK80 objects
                 handles = sendAliveMessage(handles);
             end
        end

        % Get ER60 ping state
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OperationControl/OperationMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        pingState = str2double(readbetween('<value dt="3">','</value>',response));

        % If state is inactive (16), then Z-Mux is running, so break out of
        % callback
        if isequal(pingState, 16)
            set(handles.pingTime, 'String', 'EK60s not pinging')
            drawnow nocallbacks
%             drawnow expose update

            % Change currently running variable to 0 so that getData()
            % will start looking for data again.
            handles.currentlyRunning = 0;

            % Save handles structure then exit callback
            guidata(handles.output, handles);
            return

        % Otherwise, state is active, so we can collect data
        else

            % If emitting a deep bottom ping, then put ER60 in single step and
            % send trigger signal
            if handles.emittingDeepPing

                fprintf('Emitting deep ping\n');

                % Put in Single step mode.  This needs to be done again in case
                % the Z-Mux put it back into Interval mode
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Single step</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
                handles = sendrequest(handles, rString);

                % Wait until transducers are ready to ping
                pingStatus = 1;
                while ~isequal(pingStatus,0)
                    % Get ER60 ping status
                    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/PingStatus</paramName><time>0</time></GetParameter></method></request>' char(0)];
                    [handles, response] = sendrequest(handles, rString);
                    pingStatus = str2double(readbetween('<value dt="3">','</value>',response));
                end

                % Emit ping
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/ExecuteNextPing</paramName><paramValue>1</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
                handles = sendrequest(handles, rString);

            % Otherwise, ensure that echosounder is in correct mode
            else

                % Get ER60 ping mode.
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
                [handles, response] = sendrequest(handles, rString);
                pingMode = readbetween('<value dt="8">','</value>',response);
                
                % If not using K-Sync but removing bottoms, ping mode
                % should be Interval
                if ~get(handles.checkboxKSync, 'Value') && get(handles.fixFB, 'Value')
                    
                    % Only change if it's not already Interval
                    if ~strcmp(pingMode, 'Interval')
                        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Interval</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
                        handles = sendrequest(handles, rString);
                    end
                    
                % Otherwise, ping mode should be Maximum
                else
                    
                    % Only change if not already Maximum
                    if ~strcmp(pingMode, 'Maximum')
                        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Maximum</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
                        handles = sendrequest(handles, rString);
                    end
                end
                
%                 % If using K-Sync, change mode to maximum if it isn't
%                 if get(handles.checkboxKSync, 'Value')
%                     if ~strcmp(pingMode, 'Maximum')
%                         rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Maximum</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
%                         handles = sendrequest(handles, rString);
%                     end
% 
%                 % If not using K-Sync, change mode to interval if it isn't
%                 else
%                     if ~strcmp(pingMode, 'Interval')
%                         rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Interval</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
%                         handles = sendrequest(handles, rString);
%                     end
%                 end
                
                % If ping mode was single step, need to make active again
                if strcmp(pingMode, 'Single step')
                    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>OperationControl/OperationMode</paramName><paramValue>17</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
                    handles = sendrequest(handles, rString);
                end
            end
        end
        
        % If getting bottom depths from an external sensor, then there's no
        % need to wait and collect subscription data. So first check to see
        % if data is available from an external sensor.
        if ~isempty(handles.settings.ExtDepthIP)
            
            % Encase in try/catch block, in case a problem occurs when
            % trying to read depth from external system
            try
                
                % Read depth
                fopen(handles.ExtDepth); 	% Open TCP/IP object
                fscanf(handles.ExtDepth);  	% Read and discard first packet
                depth = str2double(fscanf(handles.ExtDepth));	% Read depth
                fclose(handles.ExtDepth);  	% Close object
                                
                % Do some quality control checks on the depth
                if depth <= 5 || abs(depth-handles.depth) > 100
                    clear depth
                end
                
            % If an error occurred, report it
            catch ME
                fclose(handles.ExtDepth);  	% Close object
                clear depth
%                 disp(ME.message)
                disp('Unable to read external depth sensor!')
            end
            
            % If depth was obtained, use it. Otherwise, do bottom detection
            if exist('depth', 'var')
                disp('Depth obtained from external sensor!')
                handles.depth = depth;
                
                handles.currTime = now;
                
                % Update plotting variables. If depth obtained from
                % external sensor, then we don't know the slope, DZH, or
                % roughness, so make those NaNs.
                handles.lastDepths = [handles.lastDepths(2:end); handles.depth];
                handles.lastSlopes = [handles.lastSlopes(2:end); NaN];
                handles.lastDZHs = [handles.lastDZHs(2:end); NaN];
                handles.lastRoughnesses = [handles.lastRoughnesses(2:end); NaN];
            end
        end
            
        % If depth variable doesn't exist, either because there is no
        % external sensor or depth wasn't able to be obtained from the
        % external sensor, then download the subscription data and use it
        % to detect the bottom.
        if ~exist('depth', 'var')

            fprintf('Waiting for ping data...\n');

            % Open UDP object
            fopen(handles.u1);

            % Continuously read UDP buffer until all data is received for a ping
            while 1

                % Issue full drawnow command to register if user pressed Stop
                % button while trying to read ping data.
                drawnow

                % If stop button pressed, exit callback
                if ~get(handles.startButton, 'Value') 
                    handles.currentlyRunning = 0;
                    guidata(handles.output, handles);
                    return;
                end

                % Continually check if bytes are available in the udp object.  If
                % not, check if ER60 is still active.  If not, then exit callback
                subtimer = tic;
                while isequal(handles.u1.bytesAvailable,0)

                    % Send alive messages to ER60 and EK80 objects
                    handles = sendAliveMessage(handles);

                    % Get ER60 ping state
                    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OperationControl/OperationMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
                    [handles, response] = sendrequest(handles, rString);
                    pingState = str2double(readbetween('<value dt="3">','</value>',response));

                    % If inactive, exit callback
                    if isequal(pingState, 16)
                        fclose(handles.u1);
                        set(handles.pingTime, 'String', 'EK60s not pinging')
                        drawnow nocallbacks
%                         drawnow expose update

                        % Change currently running variable to 0 so that
                        % getData() will start looking for data again.
                        handles.currentlyRunning = 0;

                        guidata(handles.output, handles);
                        return
                    elseif toc(subtimer) > 10
                        error('Not receiving subscription data.  Resetting ER60...');
                    end
                end

                temp = nan(1,3);
                while ~isequal(temp, double('PRD'))
                    temp = [temp(2:3) double(fread(handles.u1, 1, 'int8'))];
                end
                fscanf(handles.u1, '%c', 1);        % Read extra byte

                % Read rest of header information
                fread(handles.u1,1,'int32');                 	% Sequence number
                subID = fread(handles.u1,1,'int32');            % Subscription ID
                currMsg = fread(handles.u1,1,'uint16');       	% Current message number
                totalMsg = fread(handles.u1,1,'uint16');      	% Total number of UDP messages
                numbytes = fread(handles.u1,1,'uint16');    	% Number of bytes in data field

                % If it's not the first message and all subscription variables are
                % empty, then read and discard that datagram.
                if ~isequal(currMsg, 1) && ...
                        isequal(sum(~cellfun(@isempty, handles.Power)), 0) && ...
                        isequal(sum(~cellfun(@isempty, handles.Sv)), 0) && ...
                        isequal(sum(~cellfun(@isempty, handles.Angle)), 0)

                    fprintf('Not first message and all data empty...discarding...\n');
                    fread(handles.u1, numbytes, 'int8');        % Discard data

                % Otherwise, the data may be useful
                else

                    % If first message in datagram, get time
                    if isequal(currMsg, 1)
                        time1 = fread(handles.u1,1,'int32');        % Time part 1
                        time2 = fread(handles.u1,1,'int32');        % Time part 2

                        % Calculate the ping time
                        time = double(typecast([int32(time1) int32(time2)], ...
                            'int64'))*100/1e9/60/60/24 + datenum(1601,1,1);

                        % Read datagram data if enough bytes exist
                        data = fread(handles.u1,numbytes-8, 'int8');

                        % If timestamp has changed but subscription data exists,
                        % then discard current existing contents and treat as a new
                        % ping.
                        if ~isequal(time, handles.currTime) && ...
                                (~isequal(sum(~cellfun(@isempty, handles.Power)), 0) || ...
                                ~isequal(sum(~cellfun(@isempty, handles.Sv)), 0) || ...
                                ~isequal(sum(~cellfun(@isempty, handles.Angle)), 0))

                            % Reinitialize subscription data (discard old contents)
                            handles.Power = cell(length(handles.freqs), 1);
                            handles.Sv = cell(length(handles.freqs), 1);
                            handles.Angle = cell(length(handles.freqs), 1);

                            fprintf('Timestamp differs...dumping old data.\n');
                        end

                        handles.currTime = time;    % Store current timestamp

                    % Otherwise, it's data that needs to be appended to existing
                    % data
                    else

                        % Read datagram data only if that number of bytes exist
                        data = fread(handles.u1, numbytes, 'int8');
                    end

                    % Store data in appropriate subscription cell array
                    if any(subID == handles.PowerID)       % If Power data
                        idx = find(subID == handles.PowerID);
                        handles.Power{idx} = [handles.Power{idx}; data];
                    elseif any(subID == handles.SvID)  	% If Sv data
                        idx = find(subID == handles.SvID);
                        handles.Sv{idx} = [handles.Sv{idx}; data];
                    elseif any(subID == handles.AngleID)     % If Angular data
                        idx = find(subID == handles.AngleID);
                        handles.Angle{idx} = [handles.Angle{idx}; data];
                    end

                    % If all the frequencies for all data subscriptions have data,
                    % and it's the last datagram (currMsg equals totalMsg), then
                    % break out of while loop and begin processing data
                    if currMsg == totalMsg && ...
                            isequal(sum(cellfun(@isempty, handles.Sv)), 0) && ...
                            isequal(sum(cellfun(@isempty, handles.Power)), 0) && ...
                            isequal(sum(cellfun(@isempty, handles.Angle)), 0)
                        break;
                    end
                end
            end

            % Close UDP object
            fclose(handles.u1);

            % Convert from int8 to int16
            handles.Sv = cellfun(@(x) typecast(int8(x), 'int16'), ...
                handles.Sv, 'UniformOutput', 0);
            handles.Power = cellfun(@(x) typecast(int8(x), 'int16'), ...
                handles.Power, 'UniformOutput', 0);
            handles.Angle = cellfun(@(x) typecast(int8(x), 'int16'), ...
                handles.Angle, 'UniformOutput', 0);
  
            % Sv, power, and angle data may have differing number of
            % samples, so trim to smallest variable
            for i = 1:length(handles.Sv)
                minSize = min([length(handles.Sv{i}), length(handles.Power{i}), ...
                    length(handles.Angle{i})]);
                handles.Sv{i} = handles.Sv{i}(1:minSize);
                handles.Power{i} = handles.Power{i}(1:minSize);
                handles.Angle{i} = handles.Angle{i}(1:minSize);
            end
    
            handles = findbottom(handles);
        end
        
        % Display results of detection
        fprintf('Detected bottom = %0.2f\n', handles.depth);

        % Update ER60 settings using bottom detection results
        handles = updateSettings(handles);

        % Display ping time
        fprintf('Ping time = %s\n', datestr(handles.currTime, 'ddmmmyyyy HH:MM:SS.FFF'));

        % Make passive noise measurements if checkbox is selected
        if get(handles.checkboxNoise, 'Value')

            % If noise timer exists, check to see if it's time for a new
            % measurements
            if isfield(handles, 'noiseTimer')

                % If time for a new measurements, do it
                if toc(handles.noiseTimer) > 60*str2double(handles.settings.PassiveInt)
                    handles = collectNoise(handles);

                % Otherwise, display when the next measurement occurs
                else
                    fprintf('Next noise measurements in %.0f seconds\n', 60*str2double(handles.settings.PassiveInt) - toc(handles.noiseTimer))
                end

            % If the timer doesn't exist, then collect noise data
            else
                handles = collectNoise(handles);
            end

        % If user doesn't wish to collect noise measurements, set to NaN
        else
            handles.noiseFloor = nan(1, length(handles.freqs));
        end

        fprintf('--------------------------\n');    % Add spacer

        % Re-initialize the data subscription variables
        handles.currTime = NaN;
        handles.Power = cell(length(handles.freqs), 1);
        handles.Sv = cell(length(handles.freqs), 1);
        handles.Angle = cell(length(handles.freqs), 1);

        % Update GUI and save handles structure
        drawnow nocallbacks
%         drawnow expose update
        handles.currentlyRunning = 0;       % Reset currently running flag
        guidata(handles.output, handles);

    % If Stop button is pressed, then stop timers, unsubscribe from data, and
    % close connection to ER60.
    else

        % Stop timer that has EAL collect UDP ping data
        stop(handles.subcriptionTimer);

        % Stop manual ping timer
        stop(handles.setPITimer)
        
        % Remove subscription IDs so that we know we aren't subscribed
        handles = rmfield(handles, {'PowerID', 'SvID', 'AngleID'});
        
        % Send commands to ER60 object if it is valid
        if isvalid(handles.ER60)

            %% Set the ping rate based on the logging range

            % Calculate the minimum PI given the logging range
            procTime = str2double(handles.settings.ProcBuf);
            PI = procTime + (max(handles.normRange) * 2/handles.c);

            % If using the K-Sync, the minimum ping interval must take into account
            % the time spent in groups not containing the ER60/EK80
            if get(handles.checkboxKSync, 'Value')
                PI = PI + str2double(handles.settings.KSyncAdjust);

                depthM = PI * 1500/2;
                NMEA = sprintf('$SDDPT,%.2f,0.00,*', depthM);

                % Calculate checksum
                temp = double(NMEA(2:end-1));
                checksum = 0;
                for j = 1:length(temp)
                    checksum = bitxor(checksum, temp(j));
                    checksum = uint16(checksum);
                end
                checksum = double(checksum);
                checksum = dec2hex(checksum);
                if length(checksum) == 1; checksum = strcat('0',checksum); end

                % Send depth to K-Sync 5 times every 1/2 second
                fopen(handles.KSyncDepth);
                for i = 1:5
                    fprintf(handles.KSyncDepth, sprintf('%s%s%s', NMEA, checksum, [char(13) newline]));
                    java.lang.Thread.sleep(500);
                end
                fclose(handles.KSyncDepth);   
            end

            % Put logging range back to original setting
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/SampleRange</paramName><paramValue>' int2str(max(handles.normRange)) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
            handles = sendrequest(handles, rString);
            set(handles.lRange, 'String', max(handles.normRange))

            % Set the ping interval to the maximum rate
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/Interval</paramName><paramValue>' int2str(PI*1000) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
            handles = sendrequest(handles, rString);
            set(handles.pInterval, 'String', num2str(PI))

            % Put echogram ranges and bottom detection ranges back to the logging range
            for i = 1:length(handles.freqs)

                if get(handles.softwarePulldown, 'Value') == 1
                    rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' int2str(handles.normRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                    rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                    rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/LowerDetectorLimit</paramName><paramValue>' int2str(handles.normRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                else
                    rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' int2str(handles.normRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                    rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                    rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/LowerDetectorLimit</paramName><paramValue>' int2str(handles.normRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
                end
                rString4 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/ChannelMode</paramName><paramValue>0</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];

                handles = sendrequest(handles, rString1);
                handles = sendrequest(handles, rString2);
                handles = sendrequest(handles, rString3);
                handles = sendrequest(handles, rString4);
            end

            % Get ER60 ping state
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OperationControl/OperationMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
            [handles, response] = sendrequest(handles, rString);
            pingState = str2double(readbetween('<value dt="3">','</value>',response));

            % If inactive (16), then Z-Mux is running, in which case it will put it
            % interval mode and start pinging once it's done.  Thus, we don't need
            % to do anything unless the ER60 is currently active and in single step
            % mode.
            if isequal(pingState, 17)

                % Get current ER60 ping mode.
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
                [handles, response] = sendrequest(handles, rString);
                pingMode = readbetween('<value dt="8">','</value>',response);

                % If it was in Single step mode, then changing it to interval or
                % maximum mode made it inactive.  So make it active again
                if strcmp(pingMode, 'Single step')

                    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Maximum</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
                    handles = sendrequest(handles, rString);

                    % Make ER60 active
                    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>OperationControl/OperationMode</paramName><paramValue>17</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
                    handles = sendrequest(handles, rString);
                end
            end

            % Send disconnect command
            s = ['DIS' char(0) 'Name:' handles.settings.ER60Name ...
                ';Password:' handles.settings.ER60Password char(0)];
            fwrite(handles.ER60, s, 'char');
        end

        % Delete all instruments
        if isfield(handles, 'ExtDepth')
            if isvalid(handles.ExtDepth); delete(handles.ExtDepth); end
        end
        if isfield(handles, 'KSyncDepth')
            if isvalid(handles.KSyncDepth); delete(handles.KSyncDepth); end
        end
        if isfield(handles, 'ME70')
            if isvalid(handles.ME70); delete(handles.ME70); end
        end
        if isfield(handles, 'ER60')
            if isvalid(handles.ER60); delete(handles.ER60); end
        end
        if isfield(handles, 'u1')
            if isvalid(handles.u1); delete(handles.u1); end
        end
        
        % Close connection to passive noise measurements file
        if isfield(handles, 'noiseFile')
            fclose(handles.noiseFile);
        end
        
        % If syncing with ME70, disconnect from ME70
        if get(handles.checkboxME70, 'Value')
            handles = closeME70(handles);
        end

        % Clear the status bar under the start button
        set(handles.restartTest, 'String', '');

        % Enable inputs
        enableInputs(handles);

        % Update GUI and save handles structure
        drawnow nocallbacks
%         drawnow expose update
        guidata(handles.output, handles);
    end

catch ME
    
    % Stop the timer which runs datareceived(). Only start it again once
    % connections have been re-established with the ER60.
    stop(handles.subcriptionTimer);
    
%     % Once connections have been reset, disable currentlyRunning
%     handles.currentlyRunning = 0;
%     guidata(handles.output, handles);   % Update handles structure
    
    % If Error Logs directory doesn't exist, create it
    if ~isfolder(fullfile(pwd, 'Error Logs'))
        mkdir(fullfile(pwd, 'Error Logs'))
    end
    
    % Save and display the error message.
%     save(fullfile(pwd, 'Error Logs', [datestr(now, 30) '_Error.mat']), 'ME', 'handles', '-v7.3')
    save(fullfile(pwd, 'Error Logs', [datestr(now, 30) '_Error.mat']), 'ME')
    set(handles.restartTest, 'String', ME.message);
    disp(getReport(ME));
    drawnow nocallbacks
%     drawnow expose update
    disp('Error occurred.  Resetting ER60.')
    
    % Reset the connection to the ER60.
    handles = resetER60(handles);
        
    % Once connections have been reset, disable currentlyRunning
    handles.currentlyRunning = 0;
    guidata(handles.output, handles);   % Update handles structure
    start(handles.subcriptionTimer);    
end


function handles = updateSettings(handles)

%% Get latest settings from text file
handles = readSettings(handles);

%% Update deep bottom info

% If a deep bottom was collected
if handles.currRange > handles.normRange
    handles.deepBottom = handles.depth;             % Update depth var.
    set(handles.buttonCheckBottomNow, 'Value', 0)   % Depress button
    handles.bottomCheckTimer = tic;                 % Start time over
    handles.emittingDeepPing = 0;   % Reset deep bottom collection flag
    drawnow nocallbacks
%     drawnow expose update
end

% If the deep bottom timer exists (i.e. bottom was collected), calculate
% remaining time
if isfield(handles, 'bottomCheckTimer')
    remTime = round(60*str2double(handles.settings.DeepBotInt) - toc(handles.bottomCheckTimer));
    
    % If periodically checking deep bottoms, display remaining time
    if get(handles.checkboxCheckDeepBottom, 'Value')
        if remTime > 60	% If more than a minute left, display in minutes
            set(handles.nextBottomCheck, 'String', ...
                sprintf('%0.0f minutes', ceil(remTime/60)))
        elseif remTime > 0 	% If between 0 and 60, display in seconds
            set(handles.nextBottomCheck, 'String', ...
                sprintf('%0.0f seconds', remTime))
        else                % Otherwise it's negative, so collect ping now
            set(handles.nextBottomCheck, 'String', 'Detecting now...')
        end
    else
        set(handles.nextBottomCheck, 'String', '')
    end
else
    remTime = NaN;
end

%% Update GUI with bottom detection results

% If depth was found
if ~isnan(handles.depth)
    set(handles.Depth, 'String', sprintf('%.02f', handles.depth));
    set(handles.Depth, 'BackgroundColor', [0.831 0.816 0.784]);
    set(handles.Depth, 'ForegroundColor', [0 0 0]);

% Else, see if an estimate can be obtained
else
    
    % See if currDepth file exists. If so, read contents
    fid = fopen('currDepth.txt', 'r');
    if ~isequal(fid, -1)
        disp('currDepth file exists!')
        
        C = textscan(fid, '%f,%f,%f,%f');
        fclose(fid);
        
        % Calculate time difference only if data exists for all variables
        if all(~cellfun(@isempty, C))    
            timeDiff = abs(C{1} - now) * 24 * 60 * 60; % Seconds
        end
    end
    
    % If timeDiff exists and is less than 10 seconds
    if exist('timeDiff', 'var') && timeDiff <= 10 && ~isnan(C{4})
        estDepth = C{4};
        set(handles.Depth, 'String', sprintf('%.02f', estDepth));
        set(handles.Depth, 'BackgroundColor', [66 226 244]./255);
        set(handles.Depth, 'ForegroundColor', [0.502 0.502 0.502]);
    
    % If estDepth doesn't exist but bathymetry file exists, try that
    elseif isfield(handles, 'estFunc')

        % Get longitude
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Longitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        long = str2double(readbetween('<value dt="5">','</value>',response));

        % Get latitude
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Latitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        lat = str2double(readbetween('<value dt="5">','</value>',response));

        % If trying to remove false bottoms, but location is outside the bathy
        % grid, alert user
        if get(handles.fixFB, 'Value') && ...
                (~(long >= min(handles.estFunc.F.Points(:,1)) && long <= max(handles.estFunc.F.Points(:,1))) || ...
                ~(lat >= min(handles.estFunc.F.Points(:,2)) && lat <= max(handles.estFunc.F.Points(:,2))))
            play(handles.Audio);
            msgbox('Current location is outside of bathymetry grid', ...
                'Outside Bathymetry Grid', 'warn', 'replace');
            estDepth = NaN;

        % Otherwise, calculate estimated depth
        else
            estDepth = -1*handles.estFunc.F(long, lat);
            set(handles.Depth, 'String', sprintf('%.02f', estDepth));
            set(handles.Depth, 'BackgroundColor', [0.831 0.816 0.784]);
            set(handles.Depth, 'ForegroundColor', [0.502 0.502 0.502]);
        end
    
    % Else, if a recent deep bottom detection exists
    elseif remTime > 0
        set(handles.Depth, 'String', sprintf('%.02f', handles.deepBottom));
        set(handles.Depth, 'BackgroundColor', [0.831 0.816 0.784]);
        set(handles.Depth, 'ForegroundColor', [0.502 0.502 0.502]);

    % Else, change the GUI box to yellow indicating that depth is unknown
    else
        disp('No bottom estimate available!')
        set(handles.Depth, 'BackgroundColor', [1 1 0]);
        set(handles.Depth, 'ForegroundColor', [0.502 0.502 0.502]);
    end
end

%% Update plots
set(handles.h(1), 'YData', handles.lastDepths)
set(handles.h(2), 'YData', handles.lastSlopes)
set(handles.h(3), 'YData', handles.lastDZHs)
set(handles.h(4), 'YData', handles.lastRoughnesses)

% Set x-axis limits
set(handles.axesDepth, 'XLim', [0 100]);
set(handles.axesSlope, 'XLim', [0 100]);
set(handles.axesDZH, 'XLim', [0 100]);
set(handles.axesRoughness, 'XLim', [0 100]);

%% Calculate new logging range and detection window

% Get latest maximum logging ranges
for i = 1:length(handles.freqs)
    handles.normRange(i) = str2double(eval(sprintf('handles.settings.MaxLogRange%d', handles.freqs(i)/1e3)));
end

% Get latest processing buffer time
procTime = str2double(handles.settings.ProcBuf);

% Update the normal ping rate based on max logging range
handles.normRate = round(100*(procTime + (max(handles.normRange) * 2/handles.c)))/100;

% If depth is not found
if isnan(handles.depth)
    
    % If EAL was just started and hasn't detected a depth yet
    if handles.firstPing
        
        % Update the logging range in case user changed the max range
        loggingRange = handles.normRange;
        
        % If less than 10 missed detections, update detection window in
        % case a new max range has been set
        if handles.firstPingCount < 3
            handles.RangeWindow = [0; max(handles.normRange)];   % Detection window
            handles.firstPingCount = handles.firstPingCount + 1;
            
        % If it's missed some number of pings, assume depth is beyond the
        % max logging range and update detection window accordingly
        else
            handles.firstPing = 0;
            handles.RangeWindow = [max([0 max(handles.normRange)-str2double(handles.settings.DetectionWindowSize)]); max(handles.normRange)];
        end
                
    % If bottom is below the max logging range. This condition is met if
    % the detection window either (1) covers the entire echogram range, (2)
    % is looking at the bottom of the echogram range, or (3) a deep bottom
    % ping was performed.
    elseif  isequal(handles.RangeWindow, [0; max(handles.normRange)]) || ...
            handles.RangeWindow(1) >= max(handles.normRange) - 2*str2double(handles.settings.DetectionWindowSize) || ...
            handles.RangeWindow(2) > max(handles.normRange)
        %             isequal(handles.RangeWindow, [handles.normRange-str2double(handles.settings.DetectionWindowSize); handles.normRange]) || ...

        % If a bathymetry file has been loaded, then check for an
        % estimated bottom depth
        if isfield(handles, 'estFunc')
            
            % Get estimated depth if it hasn't been done already
            if ~exist('estDepth', 'var')
                
                % Get longitude
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Longitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
                [handles, response] = sendrequest(handles, rString);
                long = str2double(readbetween('<value dt="5">','</value>',response));
                
                % Get latitude
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Latitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
                [handles, response] = sendrequest(handles, rString);
                lat = str2double(readbetween('<value dt="5">','</value>',response));
                
                % Calculate estimated depth
                estDepth = -1*handles.estFunc.F(long, lat);
            end
            
            % If a depth is found then set handles.depth equal to it so
            % that it can be used for false bottom removal, if necessary.
            % Then set the logging range and detection window to the end of
            % the echogram.
            if ~isnan(estDepth) && estDepth > max(handles.normRange)
                handles.depth = estDepth;
                handles.RangeWindow = [max([0 max(handles.normRange)-str2double(handles.settings.DetectionWindowSize)]); max(handles.normRange)];
            end
        end
                
        % If the bottom check timer exists, check to see if enough time has
        % elapsed for a new deep bottom ping.
        if isfield(handles, 'bottomCheckTimer')
            flag = toc(handles.bottomCheckTimer) >= 60*str2double(handles.settings.DeepBotInt);
            
        % If the timer didn't exist, then set flag to 1 so that a deep
        % bottom is still collected if the checkbox is checked.
        else
            flag = 1;
        end
        
        % If a depth wasn't found from the bathymetry file, and the "Check
        % now" button is pressed OR the check deep bottom checkbox is
        % checked and timer has elapsed or deepBottom is 0, then collect a
        % deep bottom ping
        if isnan(handles.depth) && ...
                (get(handles.buttonCheckBottomNow, 'Value') || ...
                (get(handles.checkboxCheckDeepBottom, 'Value') && flag))
                
                % Put ER60 in single step mode to prevent more pings from
                % causing false bottom in deep bottom data
                rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/PingMode</paramName><paramValue>Single step</paramValue><paramType>8</paramType></SetParameter></method></request>' char(0)];
                handles = sendrequest(handles, rString);

                % Set flag so that we know to emit a ping after the
                % subscription parameters have been set
                handles.emittingDeepPing = 1;

                % Start timer so we know when to emit the deep ping
                handles.deepPingTimer = tic;
                
                loggingRange = str2double(handles.settings.DeepBotRange);
                handles.RangeWindow = [handles.normRange; loggingRange];    % Set detection window to entire logging range

        % Otherwise, we have no idea what the depth is, so set logging
        % range to maximum logging range and the detection window to look
        % near the max logging range.
        else
            handles.RangeWindow = [max([0 max(handles.normRange)-str2double(handles.settings.DetectionWindowSize)]); max(handles.normRange)];
            loggingRange = handles.normRange;
        end
                
    % Otherwise, the detection window is somewhere in the
    % mid-water column, so add 15 m to both ends and continue to
    % look for the bottom
    else
        
        % Add 15 m to each end of RangeWindow
        handles.RangeWindow = [max([0 handles.RangeWindow(1)-15]);
            min([max(handles.normRange) handles.RangeWindow(2)+15])];
        
        loggingRange = min([handles.normRange handles.currRange+15],[],2);        
    end

% A depth was found
else
    % If EAL was just started, set flag to 0 in case it's missed next time
    if handles.firstPing; handles.firstPing = 0; end
    
    % Calculate the new logging range.
    loggingRange = min([handles.normRange ...
        repmat(ceil(handles.depth+str2double(handles.settings.BottomOffset)), length(handles.freqs), 1)], ...
        [], 2);

    % Set new detection window
    if handles.depth > max(handles.normRange)    % If deep bottom detection
        handles.RangeWindow = [floor(max([0 max(handles.normRange)-str2double(handles.settings.DetectionWindowSize)])); max(ceil(loggingRange))];
    else    % If normal detection
        handles.RangeWindow = [floor(max([0 handles.depth-str2double(handles.settings.DetectionWindowSize)])); max(ceil(loggingRange))];
    end    
end

% If using the ER60, set the single logging range parameter
if get(handles.softwarePulldown, 'Value') == 1
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/SampleRange</paramName><paramValue>' int2str(max(loggingRange)) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
    handles = sendrequest(handles, rString);
    
    % Update in GUI
    set(handles.lRange, 'String', max(loggingRange))

% Otherwise, if using the EK80, set the logging range based on if it's
% using single or individual logging ranges
else
    
    % Obtain variable indicating if the EK80 is using individual logging
    % ranges for each transducer
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>SounderStorageManager/IndividualChannelRecordingRange</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    IndChannelFlag = str2double(readbetween('<value dt="3">','</value>',response));

    % If flag is 1, then EK80 is set to record to individual ranges for
    % each transducer. So will need to cycle through each WBT and set the
    % sample ranges
    if IndChannelFlag
        
        % Cycle through frequencies
        for i = 1:length(handles.freqs)
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/' handles.ER60transceiverID{i} '/Range</paramName><paramValue>' int2str(loggingRange(i)) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
            handles = sendrequest(handles, rString);
        end
        
        % Update in GUI
        set(handles.lRange, 'String', 'NA')
        
    % Otherwise, only need to set the single logging range, in which case
    % we'll use the maximum of the logging ranges (should ideally all be
    % the same if the user wants that option).
    else
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/SampleRange</paramName><paramValue>' int2str(max(loggingRange)) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
        handles = sendrequest(handles, rString);
        
        % Update in GUI
        set(handles.lRange, 'String', max(loggingRange))
    end
end

% Display ping time in GUI
set(handles.pingTime, 'String', datestr(handles.currTime, 'HH:MM:SS ddmmmyyyy'))

% Display detection results in command window
fprintf('Detection window = %d to %d m\n', handles.RangeWindow(1), handles.RangeWindow(2));
fprintf('Logging range = %d\n', max(loggingRange));

% Update ME70 trigger delay if need be
if get(handles.checkboxME70, 'Value')
    try
        trigDelay = 1e3 * round(100 * loggingRange * 2/handles.c)/100;    % In ms
        rString = ['<request><clientInfo><cid>' handles.ME70CLIENTID '</cid><rid>' int2str(handles.ME70RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/SyncDelay</paramName><paramValue>' int2str(trigDelay) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
        handles = sendrequestME70(handles, rString);
    catch ME
        disp(ME.message)
        set(handles.restartTest, 'String', 'Could not connect to ME70');
        handles = closeME70(handles);
    end
end

%% Calculate ping interval

% If using manual ping interval override
if get(handles.setManualPI, 'Value')
    PI = str2double(get(handles.manualPI, 'String'));   % Get PI
    if ~isfield(handles, 'savedPI') % Save PI if it doesn't exist
        handles.savedPI = PI;
    elseif ~isequal(handles.savedPI, PI)	% If PI changed, restart timer
        handles.savedPI = PI;
        stop(handles.setPITimer)
        start(handles.setPITimer)
    end
else
    
    % Calculate the minimum PI given the logging range
    minPI = procTime + (max(loggingRange) * 2/handles.c);

    % If using the K-Sync, the minimum ping interval must take into account
    % the time spent in groups not containing the ER60/EK80
    if get(handles.checkboxKSync, 'Value')
        minPI = minPI + str2double(handles.settings.KSyncAdjust);
    end
    
    % If wanting to remove false bottoms
    if get(handles.fixFB, 'Value')
        
        % If depth was found, then use it
        if ~isnan(handles.depth)
            depth = handles.depth;
            
        % If depth was not found, then see if any recent detections exist
        % from a deep bottom ping
        else
            
            % Periodically checking for deep bottom?
            if get(handles.checkboxCheckDeepBottom, 'Value') && isfield(handles, 'deepBottom')
                depth = handles.deepBottom;
            else
                
                % Does a deep bottom exist from a recent detection?
                if remTime > 0
                    depth = handles.deepBottom;
                                        
                % Otherwise, no way of knowing depth so set to NaN
                else
                    depth = NaN;
                end
            end
        end
                
        % Get latest false bottom removal range
        remRange = str2double(handles.settings.FBRemRange);

        % Create flag variable indicating if false bottom is corrected
        FBflag = 0;
        
        % If depth is less than the ping interval
        if depth <= minPI * handles.c / 2
            
            % Calculate where a false bottom would occur if the maximum
            % ping rate were used.
            N = ceil(minPI*handles.c/(2*depth));
            RFB = N*depth - (minPI*handles.c/2);	% Depth of FB
            
            % If a false bottom would occur within the removal range, then
            % correct for it.
            if RFB < remRange
                PI = 2*N*depth/handles.c;
                FBflag = 1;
                
            % Otherwise use maximum ping rate.
            else
                PI = minPI;
            end
            
        % If depth is greater than the ping interval
        else
            
            buffer = 0;
            
            % Calculate R_AS using R_S
            N = floor(depth*2/(minPI*handles.c));
            RFB1 = depth - N*minPI*handles.c/2;
            
            % Calculate R_AS using R_S + buffer
            N = floor((depth+buffer)*2/(minPI*handles.c));
            RFB2 = (depth+buffer) - N*minPI*handles.c/2;
            
            % Calculate R_AS using R_S - buffer
            N = floor((depth-buffer)*2/(minPI*handles.c));
            RFB3 = (depth-buffer) - N*minPI*handles.c/2;
            
            % If R_AS <= R_L using R_S or R_S + buffer
            if RFB1 <= remRange || RFB2 <=  remRange
                N = floor((depth+buffer)*2/(minPI*handles.c));
                PI = 2*(depth+buffer)/(N*handles.c);
                FBflag = 1;
                
            % Else, if RS <= R_L using R_S and R_S - buffer
            elseif RFB1 > remRange && RFB3 <= remRange
                N = floor(depth*2/(minPI*handles.c));
                PI = 2*depth/(N*handles.c);
                FBflag = 1;
                
            % Otherwise, don't need to worry about false bottom, so use the
            % maximum ping rate
            else
                PI = minPI;
            end
        end
        
        % If false bottom would occur within the removal range, then update
        % status on GUI.
        if FBflag
                        
            % Update GUI
            set(handles.FBCorrected, 'String', 'False bottom corrected!');
            set(handles.FBCorrected, 'BackgroundColor', [0; 1; 0]);
            
        % Otherwise, use maximum ping rate
        else
            PI = minPI;
            
            % Update GUI
            set(handles.FBCorrected, 'String', 'No correction needed');
            set(handles.FBCorrected, 'BackgroundColor', [0.941; 0.941; 0.941]);
        end
    else	% If not wanting to remove false bottom, use minimum PI
        PI = minPI;
    end
end

% Set the ping interval
rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>AcousticDeviceSynchroniser/Interval</paramName><paramValue>' int2str(PI*1000) '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
handles = sendrequest(handles, rString);

% Update info on GUI and Command Window
fprintf('Ping interval = %0.2f\n', PI);
fprintf('Ping rate = %0.2f\n', 1/PI);
set(handles.pInterval, 'String', sprintf('%.02f', PI))

%% If using with K-Sync, send depth NMEA string
if get(handles.checkboxKSync, 'Value')
    
    % If using the K-Sync, we must take remove the time spent in the other
    % trigger groups not containing the ER60/EK80.
    PI = PI - str2double(handles.settings.KSyncAdjust);

    depthM = PI * 750;
    NMEA = sprintf('$SDDPT,%.2f,0.00,*', depthM);
    
    % Calculate checksum
    temp = double(NMEA(2:end-1));
    checksum = 0;
    for j = 1:length(temp)
        checksum = bitxor(checksum, temp(j));
        checksum = uint16(checksum);
    end
    checksum = double(checksum);
    checksum = dec2hex(checksum);
    if length(checksum) == 1; checksum = strcat('0',checksum); end
    
    % Send depth to K-Sync
    fopen(handles.KSyncDepth);
    fprintf(handles.KSyncDepth, sprintf('%s%s%s', NMEA, checksum, [char(13) newline]));
    fclose(handles.KSyncDepth);   
end

%% Update ER60 with new parameters

% Update the frequency specific settings
for i = 1:length(handles.freqs)
    
    % Get display range for that frequency
    dispRange = str2double(eval(['handles.settings.' ...
        sprintf('DispRange%d', handles.freqs(i)/1e3)]));
        
    % If checkbox is selected and display range is less than logging range,
    % change it to the set display range
    if get(handles.editDispRange, 'Value') && dispRange <= loggingRange(i)
             
        % Create string based on EK60 or EK80
        if get(handles.softwarePulldown, 'Value') == 1
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' int2str(dispRange) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        else
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' int2str(dispRange) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];            
        end
    else
        
        % Create string based on EK60 or EK80
        if get(handles.softwarePulldown, 'Value') == 1
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];        
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' int2str(loggingRange(i)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        else
            rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/RangeStart</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
            rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' int2str(loggingRange(i)) '</paramValue><paramApplyToAll>0</paramApplyToAll><paramType>5</paramType></SetParameter></method></request>' char(0)];            
        end
    end
    handles = sendrequest(handles, rString1);
    handles = sendrequest(handles, rString2);

    % Update bottom detection ranges
    if get(handles.softwarePulldown, 'Value') == 1
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/LowerDetectorLimit</paramName><paramValue>' int2str(handles.RangeWindow(2)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
    else
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/LowerDetectorLimit</paramName><paramValue>' int2str(handles.RangeWindow(2)) '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];        
    end
    handles = sendrequest(handles, rString1);
    handles = sendrequest(handles, rString2);
            
    % If logging range has changed, then update subscription
    if ~isequal(loggingRange(i), handles.currRange(i))
        
        temp = {'Power', 'Sv', 'Angle'};
        for j = 1:length(temp)
            % Update the Power data subscription range
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID ...
                '</cid>' ...
                '<rid>' int2str(handles.ER60RequestID) '</rid>' ...
                '</clientInfo><type>invokeMethod</type>' ...
                '<targetComponent>RemoteDataServer</targetComponent>' ...
                '<method><ChangeSubscription>' ...
                '<subscriptionID>' num2str(eval(['handles.' temp{j} 'ID(i)'])) '</subscriptionID>' ...
                '<dataRequest>' ...
                'SampleData' ...
                ',ChannelID=' handles.ER60transceiverID{i} ...
                ',SampleDataType=' temp{j} ...
                ',Range=' int2str(loggingRange(i)) ...
                ',RangeStart=0' ...
                '</dataRequest></ChangeSubscription></method></request>' char(0)];
            handles = sendrequest(handles, rString);
        end
    end
end
handles.currRange = loggingRange;


function handles = collectNoise(handles)
    
fprintf('Preparing for passive noise measurements\n');

handles.noiseTimer = tic;   % Restart noise collection timer

% If using EK80, obtain individual channel flag
if get(handles.softwarePulldown, 'Value') == 2
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>SounderStorageManager/IndividualChannelRecordingRange</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    IndChannelFlag = str2double(readbetween('<value dt="3">','</value>',response));
else
    IndChannelFlag = 0;
end

% Initialize variable to hold old logging ranges if using individual
% logging ranges
if IndChannelFlag
    oldLoggingRange = cell(length(handles.freqs), 1);
end

% For each frequency, store current ping mode (i.e. active or passive) then
% put into passive mode
fprintf('Putting each transceiver in passive mode\n')
currMode = cell(length(handles.freqs), 1);
for i = 1:length(handles.freqs)
    
    % Get current mode
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/ChannelMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    currMode{i} = readbetween('<value dt="3">','</value>',response);
    
    % Put into passive mode
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/ChannelMode</paramName><paramValue>1</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
    handles = sendrequest(handles, rString);
    
    % If using individual logging ranges, store
    if IndChannelFlag
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>SounderStorageManager/' handles.ER60transceiverID{i} '/Range</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        oldLoggingRange{i} = readbetween('<value dt="3">','</value>',response);
        
    % Otherwise, get and store the common logging range
    elseif i == 1
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>SounderStorageManager/SampleRange</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        oldLoggingRange = readbetween('<value dt="3">','</value>',response);
    end
end

% Calculate ping interval using logging range of passive data
PI = str2double(handles.settings.ProcBuf) + (str2double(handles.settings.PassiveRange) * 2/handles.c);

% If using with K-Sync, send depth value for the new range
if get(handles.checkboxKSync, 'Value')
    depthM = PI * 1500/2;
    NMEA = sprintf('$SDDPT,%.2f,0.00,*', depthM);

    % Calculate checksum
    temp = double(NMEA(2:end-1));
    checksum = 0;
    for j = 1:length(temp)
        checksum = bitxor(checksum, temp(j));
        checksum = uint16(checksum);
    end
    checksum = double(checksum);
    checksum = dec2hex(checksum);
    if length(checksum) == 1; checksum = strcat('0',checksum); end

    % Send depth to K-Sync 5 times every 1/2 second
    fopen(handles.KSyncDepth);
    for i = 1:5
        fprintf(handles.KSyncDepth, sprintf('%s%s%s', NMEA, checksum, [char(13) newline]));
        java.lang.Thread.sleep(500);
    end
    fclose(handles.KSyncDepth);   
end

% If using EK80 with individual logging ranges, then need to set sample
% ranges separately
if IndChannelFlag
    for i = 1:length(handles.freqs)
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/' handles.ER60transceiverID{i} '/Range</paramName><paramValue>' handles.settings.PassiveRange '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
        handles = sendrequest(handles, rString);
    end
            
% Else, set the common logging range
else
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/SampleRange</paramName><paramValue>' handles.settings.PassiveRange '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
    handles = sendrequest(handles, rString);
end

% Cycle through each GPT
detectionRanges = cell(length(handles.freqs), 1);
displayRanges = cell(length(handles.freqs), 1);
for i = 1:length(handles.freqs)

    % Get and then set bottom detection and display ranges for EK60 or EK80
    if get(handles.softwarePulldown, 'Value') == 1
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/LowerDetectorLimit</paramName><time>0</time></GetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><time>0</time></GetParameter></method></request>' char(0)];
        rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString4 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/LowerDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString5 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' handles.settings.PassiveRange '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
    else
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/LowerDetectorLimit</paramName><time>0</time></GetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><time>0</time></GetParameter></method></request>' char(0)];
        rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString4 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/LowerDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString5 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' handles.settings.PassiveRange '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
    end
    
    % Get detection ranges
    [handles, response] = sendrequest(handles, rString1);
    detectionRanges{i} = readbetween('<value dt="5">','</value>',response);
    
    % Get display ranges
    [handles, response] = sendrequest(handles, rString2);
    displayRanges{i} = readbetween('<value dt="5">','</value>',response);
    
    % Set detection and display ranges
    handles = sendrequest(handles, rString3);
    handles = sendrequest(handles, rString4);
    handles = sendrequest(handles, rString5);
end

% Monitor ER60 noise estimates from one frequency for at least one change,
% to ensure capacitors discharge
rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{1} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
[handles, response] = sendrequest(handles, rString);
oldEst = str2double(readbetween('<value dt="5">','</value>',response));
while 1
    
    % Send alive messages to ER60 and EK80 objects
    handles = sendAliveMessage(handles);
    
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{1} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    newEst = str2double(readbetween('<value dt="5">','</value>',response));
    
    if ~isequal(newEst, oldEst)
        oldEst = newEst;
        break
    end
end 

% Collect passive measurements
numPings = str2double(handles.settings.NumPassivePings);
noise = nan(numPings,length(handles.freqs));
for i = 1:numPings

    % Continually read noise estimate from single frequency until it
    % changes from last reading
    while 1
        
        % Send alive messages to ER60 and EK80 objects
        handles = sendAliveMessage(handles);
        
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{1} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        newEst = str2double(readbetween('<value dt="5">','</value>',response));

        if ~isequal(newEst, oldEst)
            oldEst = newEst;
            break
        end
    end 

    % Get the ER60 detected noise estimates for each frequency
    for j = 1:length(handles.freqs)
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{j} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        noise(i,j) = str2double(readbetween('<value dt="5">','</value>',response));
    end
end

% Store the ER60 median noise
handles.noiseFloor = median(noise, 1);
disp(handles.noiseFloor);

% Update ER60 Noise file
fprintf(handles.noiseFile, ...
    ['%s,%s' repmat(',%.2f', 1, length(handles.noiseFloor)) '\n'], ...
    datestr(now, 'ddmmmyyyy'), ...
    datestr(now, 'HHMMSS'), ...
    handles.noiseFloor(1:end-1), handles.noiseFloor(end));

% Put each ER60 frequency back into the mode that it was in before making
% passive measurements. That is, not every frequency should be placed in
% active mode if it wasn't already active
fprintf('Putting transceivers in active mode\n')
for i = 1:length(handles.freqs)
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/ChannelMode</paramName><paramValue>' currMode{i} '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
    handles = sendrequest(handles, rString);
end

% Read noise estimates to determine when a ping has elapsed 
rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{1} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
[handles, response] = sendrequest(handles, rString);
oldEst = str2double(readbetween('<value dt="5">','</value>',response));
while 1
    
    % Send alive messages to ER60 and EK80 objects
    handles = sendAliveMessage(handles);

    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{1} '_ES/ChannelProcessingCommon/NoiseEstimate</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    newEst = str2double(readbetween('<value dt="5">','</value>',response));
    
    if ~isequal(newEst, oldEst)
        break
    end
end 

fprintf('Changing logging range back to what it was\n')

% If using EK80 with individual logging ranges, then need to set sample
% ranges separately
if IndChannelFlag
    for i = 1:length(handles.freqs)
        rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/' handles.ER60transceiverID{i} '/Range</paramName><paramValue>' oldLoggingRange{i} '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
        handles = sendrequest(handles, rString);
    end
else
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>SounderStorageManager/SampleRange</paramName><paramValue>' oldLoggingRange '</paramValue><paramType>3</paramType></SetParameter></method></request>' char(0)];
    handles = sendrequest(handles, rString);
end

% Change display ranges and ER60 bottom detections back
for i = 1:length(handles.freqs)

    % Change bottom detection and display ranges for EK60 or EK80
    if get(handles.softwarePulldown, 'Value') == 1
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Depth/Layers/BottomDepthView/LowerDetectorLimit</paramName><paramValue>' detectionRanges{i} '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ScreenManager/Windows/' handles.ER60transceiverID{i} '/Echogram/World2Echogram/Range</paramName><paramValue>' displayRanges{i} '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
    else
        rString1 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/UpperDetectorLimit</paramName><paramValue>0</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString2 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>ProcessingMgr/' handles.ER60transceiverID{i} '_ES/ChannelProcessingCommon/LowerDetectorLimit</paramName><paramValue>' detectionRanges{i} '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];
        rString3 = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><SetParameter><paramName>WindowManager/ModeControl/' handles.ER60transceiverID{i} '_ES/UpperEchogram/Range</paramName><paramValue>' displayRanges{i} '</paramValue><paramType>5</paramType></SetParameter></method></request>' char(0)];        
    end
    handles = sendrequest(handles, rString1);
    handles = sendrequest(handles, rString2);
    handles = sendrequest(handles, rString3);
end

% If using with K-Sync, send depth value for the new range
PI = str2double(get(handles.pInterval, 'String'));
if get(handles.checkboxKSync, 'Value')
    depthM = PI * 1500/2;
    NMEA = sprintf('$SDDPT,%.2f,0.00,*', depthM);

    % Calculate checksum
    temp = double(NMEA(2:end-1));
    checksum = 0;
    for j = 1:length(temp)
        checksum = bitxor(checksum, temp(j));
        checksum = uint16(checksum);
    end
    checksum = double(checksum);
    checksum = dec2hex(checksum);
    if length(checksum) == 1; checksum = strcat('0',checksum); end

    % Send depth to K-Sync 5 times every 1/2 second
    fopen(handles.KSyncDepth);
    for i = 1:5
        fprintf(handles.KSyncDepth, sprintf('%s%s%s', NMEA, checksum, [char(13) newline]));
%         pause(0.5)
        java.lang.Thread.sleep(500);
    end
    fclose(handles.KSyncDepth);   
end


function [handles, response] = sendrequest(handles, str)

% Send request
header = ['REQ' char(0)];                           % Header
temp = [int2str(handles.ER60CLIENTSEQNO) ',1,1'];   % Sequence number
msgcontrol = [temp repmat(char(0), 1, 22-length(temp))];    % Msg control
s = [header msgcontrol str];                        % Put it all together

% Send command
flushinput(handles.ER60)
fwrite(handles.ER60, s, 'char');                    % Send to ER60

temp = nan(1,3);
flag = 1;
while flag
    temp = [temp(2:3) double(fread(handles.ER60, 1, 'int8'))];

    if isequal(temp, double('RES'))
        flag = 0;
    elseif isequal(temp, double('RTR'))
        fwrite(handles.ER60, s, 'char');
    end
end

% Received request response
fscanf(handles.ER60,'%c',27);
response = fscanf(handles.ER60,'%c',1400);

handles.ER60CLIENTSEQNO = handles.ER60CLIENTSEQNO+1;    % Increment seq. #


function str = readbetween(FirstPattern,LastPattern,Text)
% Extracts the string located between FirstPattern and LastPattern in the
% string Text

pat = [FirstPattern '(.*)' LastPattern];
temp = regexp(Text, pat, 'tokens');
str = temp{:}{:};


function IPAddress_Callback(~, ~, ~)


function IPAddress_CreateFcn(hObject, ~, ~)
% hObject    handle to IPAddress (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function pInterval_Callback(~, ~, ~)


function pInterval_CreateFcn(hObject, ~, ~)
% hObject    handle to pInterval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function lRange_Callback(~, ~, ~)


function lRange_CreateFcn(hObject, ~, ~) %#ok<*DEFNU>
% hObject    handle to lRange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Depth_Callback(~, ~, ~)


function Depth_CreateFcn(hObject, ~, ~)
% hObject    handle to Depth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
%     set(hObject,'BackgroundColor','white');
end


function handles = findbottom(handles)
% Function to find the bottom depth
%
% The algorithm should be as follows:
%   1.  Noise filter the data
%   2.  Only keep samples within a desired detection window.  
%   3.  Only keep samples in which Sv's from all frequencies (that haven't
%       been removed due to noise) are above some threshold.  This should
%       leave samples that are either from the bottom, fish schools, a
%       false bottom, or the transmit pulse.
%   4.  From those samples, calculate the VMR to separate the bottom from
%       fish school.  In some cases a sample will only have Sv data from
%       one frequency, but in that scenario it is not possible to
%       distinguish the bottom from a fish school.
%   5.  Find the first sample that has VMR > -23.
%   6.  

%% Define some processing parameters

Sv_threshold = -50;     % Sv threshold value
VMR_threshold = -30;    % VMR threshold
noise_threshold = -60;  % Noise floor Sv beyond which samples are removed
rollingAvgLength = 3;   % Number of meters to use for smoothing data

%% Calculate ranges for each frequency

r = arrayfun(@(x,y) linspace(0, x, y), handles.currRange, ...
    cellfun(@length, handles.Sv), 'UniformOutput', 0);

%% Convert data to same sample rate and size
% Data from each echosounder might span different ranges and contain
% different sample rates, so put them all onto a common grid

% Compute sample rates of each echosounder (samples per meter)
Fs = cellfun(@length, handles.Sv) ./ cellfun(@(x) x(end)-x(1), r);

% Create range vector spanning the longest logging range using the lowest
% sample rate
range = (0:1/min(Fs):max(handles.currRange))'; 

% Cycle through each frequency and interpolate at those ranges
Sv = nan(length(range), length(handles.freqs));
Pr = nan(length(range), length(handles.freqs));
Angle = cell(length(handles.freqs),1);
for i = 1:length(handles.freqs)
    Sv(:,i) = interp1(r{i}, double(handles.Sv{i}), range, 'linear', NaN);
    Pr(:,i) = interp1(r{i}, double(handles.Power{i}), range, 'linear', NaN);
    Angle{i} = interp1(r{i}, double(handles.Angle{i}), range, 'linear', NaN);
end

%% Downsample data to lowest sample rate
% minSize = min(cellfun(@length, handles.Sv));
% handles.Sv = cellfun(@(x) resample(double(x), minSize, length(x)), handles.Sv, 'UniformOutput', 0);
% handles.Power = cellfun(@(x) resample(double(x), minSize, length(x)), handles.Power, 'UniformOutput', 0);
% handles.Angle = cellfun(@(x) resample(double(x), minSize, length(x)), handles.Angle, 'UniformOutput', 0);

%% Convert power and angle data

% Sv and Pr data are give in EK500 format, so convert from that
Sv = Sv * 10*log10(2)/256;
Pr = Pr * 10*log10(2)/256;

% If Sv is empty (e.g. only 1 frequency that is in passive mode), then set
% depth to NaN and return to invoking function
if isempty(Sv)
    handles.depth = NaN;
    return
end

% Parse out the phase data to along- and athwart-ship and convert to
% mechanical angles
% Phase = double(reshape(typecast(int16(Angle),'int8'), 2, ...
%     length(x))'), handles.Angle, 'UniformOutput', 0);
Phase = cellfun(@(x) double(reshape(typecast(int16(x),'int8'), 2, ...
    length(x))'), Angle, 'UniformOutput', 0);

% Get Alongship angles
Alongship = cell2mat(cellfun(@(x,y) x(:,1) * 1.40625 / y, ...
    Phase, num2cell(handles.AlongshipAngleSensitivity)', ...
    'UniformOutput', 0)');

% Get Athwartship angles
Athwartship = cell2mat(cellfun(@(x,y) x(:,2) * 1.40625 / y, ...
    Phase, num2cell(handles.AthwartshipAngleSensitivity)', 'UniformOutput', 0)');

%% Remove passive-mode data

% Ignore Sv, Pr, and Angles for any frequencies that are in passive mode
for i = 1:length(handles.freqs)
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/ChannelMode</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    currMode = readbetween('<value dt="3">','</value>',response);
    
    % If mode is passive, then make all Sv's and Pr's NaNs
    if strcmp(currMode, '1')
        Sv(:,i) = NaN;
        Pr(:,i) = NaN;
        Alongship(:,i) = NaN;
        Athwartship(:,i) = NaN;
    end
end

%% Only keep data in desired range

ridx = range > 3 & range > handles.RangeWindow(1) & range < handles.RangeWindow(2);

Sv(~ridx,:) = [];
Pr(~ridx,:) = [];
Alongship(~ridx,:) = [];
Athwartship(~ridx,:) = [];
range(~ridx) = [];

%% Smooth Sv
for i = 1:size(Sv,2)
    N = ceil(rollingAvgLength / (handles.c/2) / (handles.tau(i)/4));
    Sv(:,i) = 10*log10(filter(ones(1,N)/N, 1, 10.^(Sv(:,i)./10)));
end

%% Noise filter the data
% We want to find the range at which the noise floor ramps up high enough
% that it's Sv-value is close to what we expect for the seabed (e.g. SNR <
% 10). For examples, if we expect the seabed to be above -40 dB, we find
% what range our noise floor would equal -50 dB, then remove all samples
% beyond that range, and assume the SNR is too low to accurately detect the
% seabed

% Only noise filter if there are currently noise estimates
if ~any(isnan(handles.noiseFloor))

    % Calculate noise floor Sv for each transducer
    Sv_noise = repmat(handles.noiseFloor, length(range), 1) + ...
        repmat(20*log10(range), 1, size(Sv, 2)) + ...
        2*range*handles.alpha - ...
        repmat(10*log10(handles.Pt.*(10.^(handles.G0./10)).^2.*(handles.c./handles.freqs).^2.*handles.c.*handles.tau.*(10.^(handles.psi./10))./(32*pi^2)), length(range), 1) - ...
        repmat(2*handles.Sa_corr, length(range), 1);

    % Remove all samples when the noise floor is above some threshold
    idx = Sv_noise > noise_threshold;
    Sv(idx) = NaN;
    Pr(idx) = NaN;
    Alongship(idx) = NaN;
    Athwartship(idx) = NaN;
end

%% Calculate VMR
% If only one sample is available then the variance is 0 and the VMR would
% be -Inf. In that case, we want to still be able to detect the seabed from
% the one frequency, so don't eliminate it using the VMR filter.

% Calculate echo amplitude
e = 10.^(Sv./20);

% Calculate VMR
VMR = 10*log10(nanvar(e, 0, 2)./nanmean(e, 2));

% For samples that didn't have 3 or more frequency datapoints, set the VMR
% to NaN so that it doesn't get filtered out.
idx = sum(~isnan(Sv),2) < 3;
VMR(idx) = NaN;

%% Find seabed samples

% Find Svs that are above the threshold and VMR is not less
% than its threshold
idx = find(nanmin(Sv, [], 2) > Sv_threshold & ~(VMR < VMR_threshold));

% If no samples exist, exit
if isempty(idx)
    handles.depth = NaN;    
    handles.lastDepths = [handles.lastDepths(2:end); NaN];
    handles.lastSlopes = [handles.lastSlopes(2:end); NaN];
    handles.lastDZHs = [handles.lastDZHs(2:end); NaN];
    handles.lastRoughnesses = [handles.lastRoughnesses(2:end); NaN];
    return
end

% Find seabed sample by locating the maximum Sv
[~, idx2] = max(nanmax(Sv(idx,:), [], 2));
idx = idx(idx2);

% Find sample to the left when Sv drops below the threshold
idx1 = find(nanmin(Sv(1:idx,:), [], 2) < Sv_threshold, 1, 'last');
if isempty(idx1); idx1 = 1; end

% Find sample to the right when Sv drops below the threshold
idx2 = idx-1 + find(nanmin(Sv(idx:end,:), [], 2) < Sv_threshold, 1);
if isempty(idx2); idx2 = size(Sv,1); end

%% Calculate bottom using plane fit

% Take only phase data from those indices
alpha = Alongship(idx1:idx2, :);
beta = Athwartship(idx1:idx2, :);

% Concert to x, y, and z coordinates
x = sind(alpha) .* cosd(beta) .* ...
    repmat(range(idx1:idx2),1,size(alpha,2)) ./ ...
    sqrt(1-sind(alpha).^2.*sind(beta).^2);

y = cosd(alpha) .* sind(beta) .* ...
    repmat(range(idx1:idx2),1,size(alpha,2)) ./ ...
    sqrt(1-sind(alpha).^2.*sind(beta).^2);

z = cosd(alpha) .* cosd(beta) .* ...
    repmat(range(idx1:idx2),1,size(alpha,2)) ./ ...
    sqrt(1-sind(alpha).^2.*sind(beta).^2);

% Cycle through each frequency
depth = nan(1, size(Pr,2));
dzh = nan(1, size(Pr,2));
roughness = nan(1, size(Pr,2));
slope = nan(1, size(Pr,2));
for i = 1:size(Pr,2)
        
    temp = [x(:,i) y(:,i) ones(length(x(:,i)),1)];     % Create variable matrix
    
    % If matrix is non-singular, then perform least-squares regression
    if rcond(temp'*temp) > 1e-15
        
        % Perform least squares regression
        BETA = (temp'*temp)\temp'*z(:,i);
        
        % Make sure depth is positive
        if BETA(3) < 0
            depth(i) = mean(z(:,i));
            dzh(i) = depth(i) - range(idx1);
        else
        
            % Store depth and dead zone height
            depth(i) = BETA(3);
            dzh(i) = BETA(3) - range(idx1);

            % Calculate residual sum of squares (RSS) for null hypothesis
            RSS1 = sum((z(:,i)-mean(z(:,i))).^2);

            % Calculate RSS for plane fit
            RSS2 = sum((z(:,i)-temp*BETA).^2);

            % Calculate F-statistic
            F = ((RSS1-RSS2)/(3-1))/(RSS2/(length(z(:,i))-3));

            % Calculate p-value
            p = 1-fcdf(F, (3-1), length(z(:,i))-3);

            % If p < .05, then we can reject the null hypothesis, indicating
            % that our plane fit is statistically significant and we can
            % calculate slope and roughness
            if p < 0.05
                roughness(i) = nanstd(z(:,i)-temp*BETA);
                slope(i) = acosd(1./sqrt(BETA(1).^2+BETA(2).^2+1));
            end
        end
        
    % Otherwise, data is not suitable for a plane fit, so simply use the
    % mean of Z as the depth and use it calculate dead zone height.
    else
        depth(i) = mean(z(:,i));
        dzh(i) = depth(i) - range(idx1);
    end
end

% Store depth in handles structure
handles.depth = nanmean(depth);

% Update plotting variables
handles.lastDepths = [handles.lastDepths(2:end); handles.depth];
handles.lastSlopes = [handles.lastSlopes(2:end); nanmean(slope)];
handles.lastDZHs = [handles.lastDZHs(2:end); nanmean(dzh)];
handles.lastRoughnesses = [handles.lastRoughnesses(2:end); nanmean(roughness)];


% --- Executes on button press in fixFB.
function fixFB_Callback(~, ~, handles)
% hObject    handle to fixFB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fixFB

% If checkbox is pressed and program is not running, then enable inputs
if get(handles.fixFB, 'Value')
    set(handles.FBCorrected, 'Enable', 'inactive');
    set(handles.FBCorrected, 'BackgroundColor', [0.941; 0.941; 0.941]);
    
    % If program isn't running, then enable bathymetry file inputs
    if isequal(get(handles.startButton, 'Value'), 0)
        set(handles.bathyFile, 'Enable', 'on');
        set(handles.bathyFileBrowse, 'Enable', 'on');
        set(handles.loadBathy, 'Enable', 'on');
        set(handles.bathyLoadStatus, 'Enable', 'inactive');
        
        % If bathy estimator doesn't exist, make yellow
        if ~isfield(handles, 'estFunc')
            set(handles.bathyLoadStatus, 'BackgroundColor', [1; 1; 0]);
        end
    end
    
    % Otherwise it's not removing false bottoms so everything can be disabled
else
    set(handles.bathyFile, 'Enable', 'off');
    set(handles.bathyFileBrowse, 'Enable', 'off');
    set(handles.loadBathy, 'Enable', 'off');
    set(handles.FBCorrected, 'Enable', 'off');
    set(handles.bathyLoadStatus, 'Enable', 'off');
end


function bathyFile_Callback(~, ~, ~)
% hObject    handle to bathyFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bathyFile as text
%        str2double(get(hObject,'String')) returns contents of bathyFile as a double


% --- Executes during object creation, after setting all properties.
function bathyFile_CreateFcn(hObject, ~, ~)
% hObject    handle to bathyFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in bathyFileBrowse.
function bathyFileBrowse_Callback(~, ~, handles)
% hObject    handle to bathyFileBrowse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Prompt user to select .mat file storing bathymetry estimator
[filename, pathname] = uigetfile('*.mat', 'Pick a MAT file with bathymetry data');
if ~isequal(filename,0) && ~isequal(pathname,0)
    set(handles.bathyFile, 'String', fullfile(pathname, filename))
    set(handles.bathyLoadStatus, 'String', 'File not yet loaded');
    set(handles.bathyLoadStatus, 'BackgroundColor', [1; 1; 0]);
    drawnow nocallbacks
%     drawnow expose update
end


% --- Executes on button press in loadBathy.
function loadBathy_Callback(hObject, ~, handles)
% hObject    handle to loadBathy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get file name and parts
file = get(handles.bathyFile, 'String');
[~, ~, ext] = fileparts(file);

% If file exists and is a mat-file, then continue
if exist(file, 'file') && strcmp(ext, '.mat')
    
    set(handles.bathyLoadStatus, 'String', 'Loading. Please wait...');
    set(handles.startButton, 'Enable', 'off');
    drawnow nocallbacks
%     drawnow expose update
    
    % Load mat-file
    handles.estFunc = load(file);
    
    % If correct variable exists
    if isfield(handles.estFunc, 'F')
        
        % Force extrapolation method to be none
        handles.estFunc.F.ExtrapolationMethod = 'none';
        
        set(handles.bathyLoadStatus, 'String', 'File loaded!');
        set(handles.bathyLoadStatus, 'BackgroundColor', [0; 1; 0]);
    else
        handles = rmfield(handles, 'estFunc');
        set(handles.bathyLoadStatus, 'Incorrect data in MAT-file');
        set(handles.bathyLoadStatus, 'BackgroundColor', [1; 0; 0]);
    end
    set(handles.startButton, 'Enable', 'on');
    
    % Update handles structure
    guidata(hObject, handles);
    
else
    set(handles.bathyLoadStatus, 'String', 'Specific file is not correct.');
end


function FBCorrected_Callback(~, ~, ~)
% hObject    handle to FBCorrected (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FBCorrected as text
%        str2double(get(hObject,'String')) returns contents of FBCorrected as a double


% --- Executes during object creation, after setting all properties.
function FBCorrected_CreateFcn(hObject, ~, ~)
% hObject    handle to FBCorrected (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in editDispRange.
function editDispRange_Callback(~, ~, ~)
% hObject    handle to editDispRange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of editDispRange


function pingTime_Callback(~, ~, ~)
% hObject    handle to pingTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pingTime as text
%        str2double(get(hObject,'String')) returns contents of pingTime as a double


% --- Executes during object creation, after setting all properties.
function pingTime_CreateFcn(hObject, ~, ~)
% hObject    handle to pingTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function restartTest_Callback(~, ~, ~)
% hObject    handle to restartTest (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of restartTest as text
%        str2double(get(hObject,'String')) returns contents of restartTest as a double


% --- Executes during object creation, after setting all properties.
function restartTest_CreateFcn(hObject, ~, ~)
% hObject    handle to restartTest (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in setManualPI.
function setManualPI_Callback(hObject, ~, handles)
% hObject    handle to setManualPI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Enable the ping interval settings if box is checked
if get(hObject, 'Value')
    set(handles.manualPI, 'Enable', 'on')
    set(handles.manualPIButton, 'Enable', 'on')
    handles.setPITimer.StartDelay = str2double(handles.settings.ManPingTime)*60;
    start(handles.setPITimer)           % Start timer
else
    set(handles.manualPI, 'Enable', 'off')
    set(handles.manualPIButton, 'Enable', 'off')
    stop(handles.setPITimer)           % Start timer
end


function stopManualPI(~, ~, obj)

handles = guidata(obj);

% Disable the inputs
set(handles.setManualPI, 'Value', 0)
set(handles.manualPI, 'Enable', 'off')
set(handles.manualPIButton, 'Enable', 'off')
set(handles.overrideTime, 'Enable', 'on')

guidata(handles.output, handles);   % Save handles structure


function manualPI_Callback(~, ~, ~)
% hObject    handle to manualPI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of manualPI as text
%        str2double(get(hObject,'String')) returns contents of manualPI as a double


% --- Executes during object creation, after setting all properties.
function manualPI_CreateFcn(hObject, ~, ~)
% hObject    handle to manualPI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in manualPIButton.
function manualPIButton_Callback(~, ~, ~)
% hObject    handle to manualPIButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in checkboxCheckDeepBottom.
function checkboxCheckDeepBottom_Callback(~, ~, handles)
% hObject    handle to checkboxCheckDeepBottom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkboxCheckDeepBottom

% If the box is checked, then start time and enable first check
if get(handles.checkboxCheckDeepBottom, 'Value')
    handles.deepBottom = 0;
else
    set(handles.nextBottomCheck, 'String', '')
end
guidata(handles.output, handles);


% --- Executes on button press in buttonCheckBottomNow.
function buttonCheckBottomNow_Callback(~, ~, ~)
% hObject    handle to buttonCheckBottomNow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function nextBottomCheck_Callback(~, ~, ~)
% hObject    handle to nextBottomCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nextBottomCheck as text
%        str2double(get(hObject,'String')) returns contents of nextBottomCheck as a double


% --- Executes during object creation, after setting all properties.
function nextBottomCheck_CreateFcn(hObject, ~, ~)
% hObject    handle to nextBottomCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkboxKSync.
function checkboxKSync_Callback(~, ~, ~)
% hObject    handle to checkboxKSync (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkboxKSync


function KSyncIP_Callback(~, ~, ~)
% hObject    handle to KSyncIP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of KSyncIP as text
%        str2double(get(hObject,'String')) returns contents of KSyncIP as a double


% --- Executes during object creation, after setting all properties.
function KSyncIP_CreateFcn(hObject, ~, ~)
% hObject    handle to KSyncIP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function handles = resetER60(handles)

handles.restartCount = handles.restartCount + 1;
set(handles.restartTest, 'String', sprintf('ER60 reset %d times', handles.restartCount));
fprintf('Resetting for the %d time\n', handles.restartCount);
drawnow nocallbacks
% drawnow expose update

% Delete all instruments
% delete(instrfindall)
if isfield(handles, 'ExtDepth')
    if isvalid(handles.ExtDepth); delete(handles.ExtDepth); end
end
if isfield(handles, 'KSyncDepth')
    if isvalid(handles.KSyncDepth); delete(handles.KSyncDepth); end
end
if isfield(handles, 'ME70')
    if isvalid(handles.ME70); delete(handles.ME70); end
end
if isfield(handles, 'ER60')
    if isvalid(handles.ER60); delete(handles.ER60); end
end
if isfield(handles, 'u1')
    if isvalid(handles.u1); delete(handles.u1); end
end

% Reconnect to ER60
flag = 1;
while flag
    
    % Issue full drawnow command to flush event queue and process any
    % figure changes
    drawnow;
    
    disp('Trying to reconnect to the EK60/EK80...')
    
    % Only continue trying to connect if Start button is still pressed
    if get(handles.startButton, 'Value')
        try
            handles = connect2ER60(handles);
            handles = subscribe2ER60(handles);

            % If using K-Sync, create udp object for sending depth outputs
            if get(handles.checkboxKSync, 'Value')
                handles.KSyncDepth = udp(handles.settings.KSyncIP, ...
                    str2double(handles.settings.KSyncUDPPort)); %#ok<TNMLP>
            end
            
            % If using external depth sensor, create TCP/IP object
            if ~isempty(handles.settings.ExtDepthIP)
                handles.ExtDepth = tcpip(handles.settings.ExtDepthIP, 2006); %#ok<TNMLP>
            end

            flag = 0;
        catch ME
            disp(getReport(ME))
            
            if isfield(handles, 'ExtDepth')
                if isvalid(handles.ExtDepth); delete(handles.ExtDepth); end
            end
            if isfield(handles, 'KSyncDepth')
                if isvalid(handles.KSyncDepth); delete(handles.KSyncDepth); end
            end
            if isfield(handles, 'ME70')
                if isvalid(handles.ME70); delete(handles.ME70); end
            end
            if isfield(handles, 'ER60')
                if isvalid(handles.ER60); delete(handles.ER60); end
            end
            if isfield(handles, 'u1')
                if isvalid(handles.u1); delete(handles.u1); end
            end

        end
    else
        disp('Reconnection aborted.')
        flag = 0;
    end
end


function handles = connect2ER60(handles)

try
    
    %% Get/set ER60 connection settings
    handles.ER60RequestID = 1;  % Init. ER60 request ID
    
    %% Request server info and open connection

    % Prepare and open socket connection to server.
    handles.ER60 = udp(handles.settings.ER60IP, str2double(handles.settings.RemotePort), ...
        'ByteOrder', 'littleEndian', 'DatagramTerminateMode','off');
    fopen(handles.ER60);

    % Send request server info.
    fwrite(handles.ER60, ['RSI' char(0)], 'char');

    % Read header. If nothing is sent back, then a connection setting must
    % be wrong.
    try
        header = fscanf(handles.ER60,'%c',4);	% Read header
        if ~contains(header, 'SI2')
            error('Incorrect response.  Check IP address')
        end
    catch ME
        error('No response from ER60/EK80.  Check settings')
    end

    % Get remote commandport which should be used to set up subscriptions and
    % continuously receive and respond alive messages for this connection.
    fscanf(handles.ER60,'%c',64);                   % Application Type
    fscanf(handles.ER60,'%c',64);                   % Application name
    fscanf(handles.ER60,'%c',128);                  % Application description
    fread(handles.ER60,1,'int32');                  % Application ID
    commandPort = fread(handles.ER60,1,'int32');	% Command Port
    fread(handles.ER60,1,'int32');                  % Mode
    fscanf(handles.ER60,'%c',64);                   % Host name

    % Close initial connection and open a new between our local conport
    % and the commandport provided by the ER60 server.
    fclose(handles.ER60);
    handles.ER60 = udp(handles.settings.ER60IP, commandPort, ...
        'ByteOrder', 'littleEndian', ...
        'DatagramTerminateMode', 'off', ...
        'InputBufferSize', 1e4);
    fopen(handles.ER60);

    %% Connect to ER60 server

    % Try to connect with a user and password which must be defined in
    % server ER60 application (Users and Passwords dialogue).
    fwrite(handles.ER60, ['CON' char(0) 'Name:' ...
        handles.settings.ER60Name ';Password:' ...
        handles.settings.ER60Password char(0)], 'char');

    % Receive response
    header = fscanf(handles.ER60,'%c',4);
    if contains(header, 'RES')
        % Received request response
        fscanf(handles.ER60,'%c',4);
        fscanf(handles.ER60,'%c',22);
        response = fscanf(handles.ER60,'%c',1400);
    else
        error('Unknown response: %s', header);
    end

    % Get CLIENTID
    handles.ER60CLIENTID = regexp(response, 'ClientID:(\d+),', 'tokens');
    handles.ER60CLIENTID = handles.ER60CLIENTID{:}{:};

    % Initialiaze client sequence number
    handles.ER60CLIENTSEQNO = 1;

    %% Get transceiver IDs

    % Send request to get transceiver IDs
    rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/Channels</paramName><time>0</time></GetParameter></method></request>' char(0)];
    [handles, response] = sendrequest(handles, rString);
    transceiverID = readbetween('<value dt="8200">','</value>',response);
    handles.ER60transceiverID = regexp(transceiverID, '[^,]*', 'match');    % transceiver IDs for each frequency

    % Get Nominal frequencies based on ER60 or EK80
    if get(handles.softwarePulldown, 'Value') == 1
    
        % Parse out available frequencies from the transceiver IDs
        handles.freqs = regexp(handles.ER60transceiverID, '(\d+) kHz', 'tokens');
        handles.freqs = 1e3*str2double(cellfun(@(x) x{1}{1}, ...
            handles.freqs, 'UniformOutput', 0));
    else
        
        % Loop through each transceiver and obtain nominal frequency
        for i = 1:length(handles.ER60transceiverID)
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>TransceiverMgr/' handles.ER60transceiverID{i} '/Frequency</paramName><time>0</time></GetParameter></method></request>' char(0)];
            [handles, response] = sendrequest(handles, rString);
            handles.freqs(i) = ...
                str2double(readbetween('<value dt="5">','</value>',response));
        end
    end

    % Sort frequencies to ensure they are ordered correctly
    [handles.freqs, temp] = sort(handles.freqs);
    handles.ER60transceiverID = handles.ER60transceiverID(temp);
    
catch ME
        
    % Delete all instruments
%     delete(instrfindall)
    if isfield(handles, 'ExtDepth')
        if isvalid(handles.ExtDepth); delete(handles.ExtDepth); end
    end
    if isfield(handles, 'KSyncDepth')
        if isvalid(handles.KSyncDepth); delete(handles.KSyncDepth); end
    end
    if isfield(handles, 'ME70')
        if isvalid(handles.ME70); delete(handles.ME70); end
    end
    if isfield(handles, 'ER60')
        if isvalid(handles.ER60); delete(handles.ER60); end
    end
    if isfield(handles, 'u1')
        if isvalid(handles.u1); delete(handles.u1); end
    end

    
    error(ME.message);
end


function handles = subscribe2ER60(handles)

try
    
    %% If subscription IDs exist, then unsubscribe and delete
    if isfield(handles, 'PowerID')
        for i = 1:length(handles.freqs)

            % Stop Power subscription
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>RemoteDataServer</targetComponent><method><Unsubscribe><subscriptionID>' num2str(handles.PowerID(i)) '</subscriptionID></Unsubscribe></method></request>' char(0)];
            handles = sendrequest(handles, rString);

            % Stop Sv subscription
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>RemoteDataServer</targetComponent><method><Unsubscribe><subscriptionID>' num2str(handles.SvID(i)) '</subscriptionID></Unsubscribe></method></request>' char(0)];
            handles = sendrequest(handles, rString);

            % Stop Angle subscription
            rString = ['<request><clientInfo><cid>' handles.ER60CLIENTID '</cid><rid>' int2str(handles.ER60RequestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>RemoteDataServer</targetComponent><method><Unsubscribe><subscriptionID>' num2str(handles.AngleID(i)) '</subscriptionID></Unsubscribe></method></request>' char(0)];
            handles = sendrequest(handles, rString);
        end
        
        handles = rmfield(handles, {'PowerID', 'SvID', 'AngleID'});
    end
    
    %% Subscribe to data for all ER60 frequencies
    temp = {'Sv', 'Power', 'Angle'};    % Subscription variables

    % Create new udp object for receiving data at the specified client dataport
    handles.u1 = udp(handles.settings.ER60IP, ...
        'ByteOrder', 'littleEndian', ...
        'DatagramTerminateMode', 'off', ...
        'InputBufferSize', 4e7);
    
    % Open udp object to get a local port then close it
    fopen(handles.u1);
    localPort = get(handles.u1, 'localPort');
    fclose(handles.u1);
    
    % Set udp object to that localPort
    set(handles.u1, 'localPort', localPort)

    % Loop through Sv, Power, and Angle subscriptions
    for i = 1:length(temp)

        % Subscribe for each frequency
        for j = 1:length(handles.freqs)

            % Request string for Sv data
            rString = ['<request><clientInfo><cid>' ...
                handles.ER60CLIENTID ...
                '</cid>' ...
                '<rid>' int2str(handles.ER60RequestID) '</rid>' ...
                '</clientInfo><type>invokeMethod</type>' ...
                '<targetComponent>RemoteDataServer</targetComponent><method>' ...
                '<Subscribe><requestedPort>' ...
                int2str(localPort) ...
                '</requestedPort><dataRequest>' ...
                'SampleData,ChannelID=' handles.ER60transceiverID{j} ...
                ',SampleDataType=' temp{i} ...
                ',Range=' int2str(handles.currRange(j)) ...
                ',RangeStart=0' ...
                '</dataRequest></Subscribe></method></request>' char(0)];

            try
                [handles, response] = sendrequest(handles, rString);
            catch ME
                error('Error during subscription.  Stoppin EAL');
            end
            temp2 = readbetween('<subscriptionID dt="3">','</subscriptionID>',response);
            eval(['handles.' temp{i} 'ID(j) = ' temp2 ';']);
        end
    end

    % Initialize Sv cell arrays to hold data for each frequency
    handles.Power = cell(length(handles.freqs), 1);
    handles.Sv = cell(length(handles.freqs), 1);
    handles.Angle = cell(length(handles.freqs), 1);
    
catch ME

    % Delete all instruments
%     delete(instrfindall)
    if isfield(handles, 'ExtDepth')
        if isvalid(handles.ExtDepth); delete(handles.ExtDepth); end
    end
    if isfield(handles, 'KSyncDepth')
        if isvalid(handles.KSyncDepth); delete(handles.KSyncDepth); end
    end
    if isfield(handles, 'ME70')
        if isvalid(handles.ME70); delete(handles.ME70); end
    end
    if isfield(handles, 'ER60')
        if isvalid(handles.ER60); delete(handles.ER60); end
    end
    if isfield(handles, 'u1')
        if isvalid(handles.u1); delete(handles.u1); end
    end

    
    error(ME.message);
end


function handles = readSettings(handles)
% Attempts to read a Settings.txt file various EAL parameters. If the files
% exists, it loads and returns those parameters. If the file doesn't exist,
% one is created with default parameters

% If file doesn't exist, create it
if exist('Settings.txt', 'file') ~= 2
    writeSettingsFile;
end
    
% Read text file
data = fileread('Settings.txt');

handles.settings = regexp(data, ['IP Address =\s*(?<ER60IP>[^\s%]*).*' ...
    'Remote Port =\s*(?<RemotePort>[^\s%]*).*' ...
    'Name =\s*(?<ER60Name>[^\s%]*).*' ...
    'Password =\s*(?<ER60Password>[^\s%]*).*' ...
    '18 kHz =\s*(?<MaxLogRange18>[^\s%]*).*' ...
    '38 kHz =\s*(?<MaxLogRange38>[^\s%]*).*' ...
    '70 kHz =\s*(?<MaxLogRange70>[^\s%]*).*' ...
    '120 kHz =\s*(?<MaxLogRange120>[^\s%]*).*' ...
    '200 kHz =\s*(?<MaxLogRange200>[^\s%]*).*' ...
    '333 kHz =\s*(?<MaxLogRange333>[^\s%]*).*' ...
    'Processing buffer =\s*(?<ProcBuf>[^\s%]*).*' ...
    'Bottom Offset =\s*(?<BottomOffset>[^\s%]*).*' ...
    'Manual Ping Interval Override Time =\s*(?<ManPingTime>[^\s%]*).*' ...
    'External Depth Input IP =\s*(?<ExtDepthIP>[^\s%]*).*' ...    
    'Detection Window Size =\s*(?<DetectionWindowSize>[^\s%]*).*' ...
    'Deep Bottom Ping Interval =\s*(?<DeepBotInt>[^\s%]*).*' ...
    'Deep Bottom Ping Range =\s*(?<DeepBotRange>[^\s%]*).*' ...
    'Passive Noise Interval =\s*(?<PassiveInt>[^\s%]*).*' ...
    'Number of passive pings =\s*(?<NumPassivePings>[^\s%]*).*' ...
    'Passive Noise Range =\s*(?<PassiveRange>[^\s%]*).*' ...
    'Removal Range =\s*(?<FBRemRange>[^\s%]*).*' ...
    '18 kHz Range =\s*(?<DispRange18>[^\s%]*).*' ...
    '38 kHz Range =\s*(?<DispRange38>[^\s%]*).*' ...
    '70 kHz Range =\s*(?<DispRange70>[^\s%]*).*' ...
    '120 kHz Range =\s*(?<DispRange120>[^\s%]*).*' ...
    '200 kHz Range =\s*(?<DispRange200>[^\s%]*).*' ...
    '333 kHz Range =\s*(?<DispRange333>[^\s%]*).*' ...
    'K-Sync IP =\s*(?<KSyncIP>[^\s%]*).*' ...
    'K-Sync UDP Port =\s*(?<KSyncUDPPort>[^\s%]*).*' ...
    'Non-ER60/EK80 Group Lengths =\s*(?<KSyncAdjust>[^\s%]*).*' ...
    'ME70 Remote Port =\s*(?<ME70RemotePort>[^\s%]*).*' ...
    'ME70 Name =\s*(?<ME70Name>[^\s%]*).*' ...
    'ME70 Password =\s*(?<ME70Password>[^\s%]*).*' ...
    'ME70 Connection Port =\s*(?<ME70ConPort>[^\s%]*).*' ...
    ], 'names');


function writeSettingsFile

% Create file and get identifier
fid = fopen('Settings.txt', 'w');

% Write file
fprintf(fid, '// ER60/EK80 Remoting Settings\r\n');
fprintf(fid, 'IP Address = 192.168.123.105\t%% Local IP address defined in ER60/EK80 Remoting dialog\r\n');
fprintf(fid, 'Remote Port = 37655\t%% Local Port defined in ER60 Remoting dialog\r\n');
fprintf(fid, 'Name = Simrad\t%% Username defined in ER60/EK80 Users and Passwords dialog\r\n');
fprintf(fid, 'Password =\t%% Password for the above username\r\n\r\n');

fprintf(fid, '// Max Logging Range Settings\r\n');
fprintf(fid, '18 kHz = 750\t%% Maximum range to log 18 kHz data (m)\r\n');
fprintf(fid, '38 kHz = 750\t%% Maximum range to log 38 kHz data (m)\r\n');
fprintf(fid, '70 kHz = 750\t%% Maximum range to log 70 kHz data (m)\r\n');
fprintf(fid, '120 kHz = 750\t%% Maximum range to log 120 kHz data (m)\r\n');
fprintf(fid, '200 kHz = 750\t%% Maximum range to log 200 kHz data (m)\r\n');
fprintf(fid, '333 kHz = 750\t%% Maximum range to log 333 kHz data (m)\r\n\r\n');

fprintf(fid, '// Ping Settings\r\n');
fprintf(fid, 'Processing buffer = 0.16\t%% Time buffer to account for ER60 processing (s)\r\n');
fprintf(fid, 'Bottom Offset = 60\t%% Logging range is bottom depth plus this offset (m)\r\n');
fprintf(fid, 'Manual Ping Interval Override Time = 5\t%% Override time to use manual ping interval (min)\r\n\r\n');

fprintf(fid, '// Bottom Detection Settings\r\n');
fprintf(fid, 'External Depth Input IP = \t%% Enter IP of system supplying DBT or DBS inputs, blank if none\r\n');
fprintf(fid, 'Detection Window Size = 15\t%% Detection window is last depth +- this range (m)\r\n\r\n');

fprintf(fid, '// Deep Bottom Ping Settings\r\n');
fprintf(fid, 'Deep Bottom Ping Interval = 10\t%% Time between deep bottom detections (min)\r\n');
fprintf(fid, 'Deep Bottom Ping Range = 5000\t%% Range (m) of deep bottom pings, if no bathymetry file\r\n\r\n');

fprintf(fid, '// Noise Measurement Settings\r\n');
fprintf(fid, 'Passive Noise Interval = 30\t%% Time between passive noise measurements (min)\r\n');
fprintf(fid, 'Number of passive pings = 3\t%% Number of passive pings to collect for noise measurement\r\n');
fprintf(fid, 'Passive Noise Range = 100\t%% Range (m) of passive noise pings\r\n\r\n');

fprintf(fid, '// False Bottom Removal Settings\r\n');
fprintf(fid, 'Removal Range = 250\t%% Range above which false bottoms will be removed (m)\r\n\r\n');

fprintf(fid, '// Display Settings\r\n');
fprintf(fid, '18 kHz Range = 750\t%% Display range of 18 kHz echogram (m)\r\n');
fprintf(fid, '38 kHz Range = 750\t%% Display range of 38 kHz echogram (m)\r\n');
fprintf(fid, '70 kHz Range = 750\t%% Display range of 70 kHz echogram (m)\r\n');
fprintf(fid, '120 kHz Range = 750\t%% Display range of 120 kHz echogram (m)\r\n');
fprintf(fid, '200 kHz Range = 750\t%% Display range of 200 kHz echogram (m)\r\n');
fprintf(fid, '333 kHz Range = 750\t%% Display range of 333 kHz echogram (m)\r\n\r\n');

fprintf(fid, '// K-Sync Settings\r\n');
fprintf(fid, 'K-Sync IP = 157.237.60.169\t%% IP Address of K-Sync Synchronization Unit\r\n');
fprintf(fid, 'K-Sync UDP Port = 4502\t%% UDP port to sending K-Sync data (typically not changed)\r\n');
fprintf(fid, 'Non-ER60/EK80 Group Lengths = 0.02\t%% Time spent in groups not containing the ER60/EK80 (s)\r\n\r\n');

fprintf(fid, '// ME70 Settings\r\n');
fprintf(fid, 'ME70 Remote Port = 37656\t%% Local Port defined in ME70 Remoting dialog\r\n');
fprintf(fid, 'ME70 Name = Simrad\t%% Username defined in ME70 Users and Passwords dialog\r\n');
fprintf(fid, 'ME70 Password =\t%% Password for the above username\r\n');
fprintf(fid, 'ME70 Connection Port = 2051\t%% UDP Port for comms to ME70 server (typically not changed)');

fclose(fid);


% --- Executes on button press in buttonSettings.
function buttonSettings_Callback(~, ~, ~)
% hObject    handle to buttonSettings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If Settings.txt doesn't exist, create it
if exist(fullfile(pwd, 'Settings.txt'), 'file') ~= 2
    writeSettingsFile;
end

% Open Settings file in Notepad
eval('!Notepad Settings.txt &')


% --- Executes on button press in checkboxME70.
function checkboxME70_Callback(~, ~, handles)
% hObject    handle to checkboxME70 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkboxME70

% Only enable inputs if the checkbox is checked while the program is not
% running
if get(handles.checkboxME70, 'Value')
    set(handles.ME70IPAddress, 'Enable', 'on');
    
% Otherwise it was unchecked, so disable inputs and close UDP object
else
    set(handles.ME70IPAddress, 'Enable', 'off');
end


function ME70IPAddress_Callback(~, ~, ~)
% hObject    handle to ME70IPAddress (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ME70IPAddress as text
%        str2double(get(hObject,'String')) returns contents of ME70IPAddress as a double


% --- Executes during object creation, after setting all properties.
function ME70IPAddress_CreateFcn(hObject, ~, ~)
% hObject    handle to ME70IPAddress (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function handles = sendAliveMessage(handles)

% Send alive message to ER60 object
fwrite(handles.ER60, ['ALI' char(0) ...
    'ClientID:' handles.ER60CLIENTID ...
    ',SeqNo:' int2str(handles.ER60CLIENTSEQNO) ...
    char(0)], 'char');


function sendalivemessagesME70(~, ~, obj)

handles = guidata(obj);

% Respond with alive
alive = ['ALI' char(0) 'ClientID:' handles.ME70CLIENTID ',SeqNo:' ...
    int2str(handles.ME70CLIENTSEQNO) char(0)];
fwrite(handles.ME70, alive, 'char');


function [handles, response] = sendrequestME70(handles, str)

% Send request
header = ['REQ' char(0)];                           % Header
temp = [int2str(handles.ME70CLIENTSEQNO) ',1,1'];   % Sequence number
msgcontrol = [temp repmat(char(0), 1, 22-length(temp))];    % Msg control
s = [header msgcontrol str];                        % Put it all together

flushinput(handles.ME70);                           % Flush input buffer
fwrite(handles.ME70, s, 'char');                    % Send to ER60

% Continuously read buffer until 'RES' is received
temp = nan(1,3);
sendTimer = tic;
while ~isequal(temp, double('RES'))
    
    % Only read when there is data on the input buffer
    if ~isequal(handles.ME70.bytesAvailable,0)
        temp = [temp(2:3) double(fread(handles.ME70, 1, 'int8'))];
        
    % If more than 2 seconds have elapsed without data on the input buffer,
    % then close connection to ME70
    elseif toc(sendTimer) > 5
        set(handles.restartTest, 'String', 'Lost communication with ME70');
        handles = closeME70(handles);
        return
    end
end

% Received request response
fscanf(handles.ME70, '%c', 1);        % Read extra byte
fscanf(handles.ME70,'%c',4);
fscanf(handles.ME70,'%c',22);
response = fscanf(handles.ME70,'%c',1400);
handles.ME70CLIENTSEQNO = handles.ME70CLIENTSEQNO+1;    % Increment seq. #


function handles = closeME70(handles)

% Uncheck checkbox
set(handles.checkboxME70, 'Value', 0)

% Send disconnect command
s = ['DIS' char(0) 'Name:' handles.settings.ME70Name ...
    ';Password:' handles.settings.ME70Password char(0)];
fwrite(handles.ME70, s, 'char');

% Stop sending alive messages
if isfield(handles, 'ME70timerobj')
    stop(handles.ME70timerobj)
end

% Close connection
fclose(handles.ME70);
delete(handles.ME70);


% --- Executes on selection change in softwarePulldown.
function softwarePulldown_Callback(~, ~, ~)
% hObject    handle to softwarePulldown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns softwarePulldown contents as cell array
%        contents{get(hObject,'Value')} returns selected item from softwarePulldown


% --- Executes during object creation, after setting all properties.
function softwarePulldown_CreateFcn(hObject, ~, ~)
% hObject    handle to softwarePulldown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
