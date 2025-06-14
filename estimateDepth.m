function varargout = estimateDepth(varargin)
% ESTIMATEDEPTH MATLAB code for estimateDepth.fig
%      ESTIMATEDEPTH, by itself, creates a new ESTIMATEDEPTH or raises the existing
%      singleton*.
%
%      H = ESTIMATEDEPTH returns the handle to a new ESTIMATEDEPTH or the handle to
%      the existing singleton*.
%
%      ESTIMATEDEPTH('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ESTIMATEDEPTH.M with the given input arguments.
%
%      ESTIMATEDEPTH('Property','Value',...) creates a new ESTIMATEDEPTH or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before estimateDepth_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to estimateDepth_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help estimateDepth

% Last Modified by GUIDE v2.5 29-Jun-2016 15:17:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @estimateDepth_OpeningFcn, ...
                   'gui_OutputFcn',  @estimateDepth_OutputFcn, ...
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
% End initialization code - DO NOT EDIT


% --- Executes just before estimateDepth is made visible.
function estimateDepth_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to estimateDepth (see VARARGIN)

% Choose default command line output for estimateDepth
handles.output = hObject;

% Create timer for updating depths
handles.depthTimer = timer('ExecutionMode', 'fixedSpacing', ...
    'Period', 1, ...
    'Name', 'Depth Timer', ...
    'BusyMode', 'drop', ...
    'TimerFcn', @(obj, eventdata) depthTimerFcn(handles.output));

% Create timer for sending alive messages
handles.aliveTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', 1, ...
    'Name', 'Alive Message Timer', ...
    'BusyMode', 'drop', ...
    'TimerFcn', @(obj, eventdata) sendAliveMessage(handles.output));

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes estimateDepth wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = estimateDepth_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function depthBox_Callback(hObject, eventdata, handles)
% hObject    handle to depthBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of depthBox as text
%        str2double(get(hObject,'String')) returns contents of depthBox as a double


% --- Executes during object creation, after setting all properties.
function depthBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to depthBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ER60IP_Callback(hObject, eventdata, handles)
% hObject    handle to ER60IP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ER60IP as text
%        str2double(get(hObject,'String')) returns contents of ER60IP as a double


% --- Executes during object creation, after setting all properties.
function ER60IP_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ER60IP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in startButton.
function startButton_Callback(hObject, ~, handles)
% hObject    handle to startButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get latest handles structure
handles = guidata(handles.output);

% If Start button was pressed
if get(hObject, 'Value')
        
    % Set some program defaults
    handles.IP = get(handles.ER60IP, 'String');
    handles.remotePort = 37655;
    handles.ER60Name = 'Simrad';
    handles.ER60Password = '';
    
    % Close all open file handlers
    fclose('all');
    
    % Change button to display Stop
    set(hObject, 'String', 'Stop', 'BackgroundColor', 'r')
    drawnow nocallbacks
    
    % Try to connect to ER60
    try
        handles = connect2ER60(handles);
        
    % If connection was unsuccessul, display message and change button
    catch ME
        disp(ME.message)
        
        % Change button to display Start
        set(handles.startButton, 'Value', 0, 'String', 'Start', 'BackgroundColor', 'g')
        return
    end
    
    % Update handles structure
    guidata(handles.output, handles)
        
    % Start timer
    start(handles.depthTimer);        
end


function depthTimerFcn(obj)

% Get latest handles structure
handles = guidata(obj);
drawnow nocallbacks

try
    
    % Only run if start button is still pressed
    if get(handles.startButton, 'Value')    
            
        % Get longitude
        rString = ['<request><clientInfo><cid>' handles.clientID '</cid><rid>' int2str(handles.requestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Longitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        longitude = str2double(readbetween('<value dt="5">','</value>',response));
        
        % Get latitude
        rString = ['<request><clientInfo><cid>' handles.clientID '</cid><rid>' int2str(handles.requestID) '</rid></clientInfo><type>invokeMethod</type><targetComponent>ParameterServer</targetComponent><method><GetParameter><paramName>OwnShip/Latitude</paramName><time>0</time></GetParameter></method></request>' char(0)];
        [handles, response] = sendrequest(handles, rString);
        latitude = str2double(readbetween('<value dt="5">','</value>',response));
        
        % Get depth at that position
        depth = -getDepth(latitude, longitude);
                
        % Write results to a text file if none of them are NaN
        if all(~isnan([longitude, latitude, depth]))
            fid = fopen('currDepth.txt', 'w');
            fprintf(fid, '%s,%f,%f,%f', datetime('now'), latitude, longitude, depth);
            fclose(fid);
        end
        
        % Update GUI with depth
        set(handles.depthBox, 'String', sprintf('%.2f', depth))
        drawnow nocallbacks
                
        guidata(handles.output, handles)
        
    % Otherwise, if stop button was pressed, disconnect
    else
        
        % Change button to display Start
        set(handles.startButton, 'String', 'Start', 'BackgroundColor', 'g')
        drawnow nocallbacks

        % Stop timer
        stop(handles.depthTimer);
%         stop(handles.aliveTimer)

        % Disconnect from ER60
        fwrite(handles.ER60, ['DIS' char(0) ...
            'Name:' handles.ER60Name ...
            ';Password:' handles.ER60Password ...
            char(0)], 'char');

        % Delete all instruments
        delete(udpportfind)
    end
        
% If an error occurred
catch ME
    disp(getReport(ME))
    
    % Stop timers
    stop(handles.depthTimer)    % Timer for obtaining depths
%     stop(handles.aliveTimer)    % Timer for sending alive message
    
    % Delete all instruments
    delete(instrfindall)
    
    % Continually try to reconnect to ER60
    flag = 1;
    while flag

        % Issue full drawnow command to flush event queue and process any
        % figure changes
        drawnow;

        disp('Trying to reconnect...')

        % Continually try to reconnect to the ER60 unless the stop button is
        % pressed
        if get(handles.startButton, 'Value')
            try
                handles = connect2ER60(handles);
                flag = 0;
                disp('Reconnected!')
                
                % Update handles structure
                guidata(handles.output, handles)

                % Start timers
%                 start(handles.aliveTimer)
                start(handles.depthTimer);    

            catch ME
                disp(getReport(ME))
            end
        else
            disp('Reconnection aborted.')
            flag = 0;
            
            % Change button to display Start
            set(handles.startButton, 'String', 'Start', 'BackgroundColor', 'g')
            drawnow nocallbacks
        end
    end
end


function handles = connect2ER60(handles)
    
%% Get/set ER60 connection settings
handles.requestID = 1;  % Init. request ID

%% Request server info and open connection

% Prepare and open socket connection to server.
handles.ER60 = udp(handles.IP, handles.remotePort, ...
    'ByteOrder', 'littleEndian', 'DatagramTerminateMode','off');
fopen(handles.ER60);

% Send request server info.
fwrite(handles.ER60, ['RSI' char(0)], 'char');

% Read header.  If nothing is sent back, then a connection setting must be
% wrong.
try
    header = fscanf(handles.ER60,'%c',4);	% Read header
    if ~strcmp(header, ['SI2' char(0)])
        error('Incorrect response.  Check IP address')
    end
catch ME
    error('No response from ER60.  Check settings')
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
handles.ER60 = udp(handles.IP, commandPort, ...
    'ByteOrder', 'littleEndian', ...
    'DatagramTerminateMode', 'off', ...
    'InputBufferSize', 1e4);
fopen(handles.ER60);

%% Connect to ER60 server

% Try to connect with a user and password which must be defined in
% server ER60 application (Users and Passwords dialogue).
fwrite(handles.ER60, ['CON' char(0) ...
    'Name:' handles.ER60Name ...
    ';Password:' handles.ER60Password char(0)], 'char');

% Receive response
header = fscanf(handles.ER60,'%c',4);
if strcmp(header, ['RES' char(0)])
    % Received request response
    fscanf(handles.ER60,'%c',4);
    fscanf(handles.ER60,'%c',22);
    response = fscanf(handles.ER60,'%c',1400);
else
    error('Unknown response: %s', header);
end

% Get CLIENTID
handles.clientID = regexp(response, 'ClientID:(\d+),', 'tokens');
handles.clientID = handles.clientID{:}{:};

% Initialiaze client sequence number
handles.clientSeqNo = 1;


function [handles, response] = sendrequest(handles, str)

% Send request
header = ['REQ' char(0)];                           % Header
temp = [int2str(handles.clientSeqNo) ',1,1'];   % Sequence number
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

handles.clientSeqNo = handles.clientSeqNo+1;    % Increment seq. #


function str = readbetween(FirstPattern,LastPattern,Text)
% Extracts the string located between FirstPattern and LastPattern in the
% string Text

pat = [FirstPattern '(.*)' LastPattern];
temp = regexp(Text, pat, 'tokens');
str = temp{:}{:};


function depth = getDepth(latitude, longitude)
%GETDEPTH Estimate seabed depth at specific location.
%   DEPTH = GETDEPTH(LATITUDE, LONGITUDE) estimates the seabed depth DEPTH
%   at specified coordinate(s). LATITUDE and LONGITUDE coordinates can
%   either be numeric arrays specifying decimal degrees or cell arrays of
%   strings specifying degrees, minutes, and seconds or GPS degrees. DEPTH
%   is returned in meters, where negative values correspond to depths below
%   sea level.
%
%   If LATITUDE and LONGITUDE are cell arrays of strings, the hemisphere
%   designator (N/S/E/W) must prepend the location (e.g. 'N 37 23 30') and
%   all values must be separated by spaces.
%
%   This function uses the Marine Geoscience Data System website to obtain
%   seabed estimates from their Global Multi-Resolution Topography (GMRT)
%   dataset. Thus, an Internet connection is required.
%
%   Examples:
%       getDepth(32.930667, -117.3175)
%       getDepth('N 32 55 50', 'W 117 19 3')
%       getDepth('N 32 55.84', 'W 117 19.05')
%       getDepth([33.52 35.14], [-119.88 -123.35])
%       getDepth({'N 33 31 12' 'N 35 8 24'}, {'W 119 52 48' 'W 123 21 0'})
%       getDepth({'N 33 31.2' 'N 35 8.4'}, {'W 119 52.8' 'W 123 21.0'})
%
%   Reference:
%       Ryan, W.B.F., S.M. Carbotte, J.O. Coplan, S. O'Hara, A. Melkonian,
%       R. Arko, R.A. Weissel, V. Ferrini, A. Goodwillie, F. Nitsche, J.
%       Bonczkowski, and R. Zemsky (2009), Global Multi-Resolution
%       Topography synthesis, Geochem. Geophys. Geosyst., 10, Q03014, doi:
%       10.1029/2008GC002332

% Created by Josiah Renfree, May 16, 2016
% Advanced Survey Technologies / Southwest Fisheries Science Center
% National Oceanic and Atmospheric Administration

% Verify that two inputs were given
if nargin ~= 2
    error('Function requires two input arguments giving the GPS coordinates.')

% Verify that both inputs are the same type (e.g. both numeric arrays)
elseif ~strcmp(class(latitude), class(longitude))
    error('Both inputs must be of the same type, e.g. numeric arrays or cell arrays.')

% If inputs are single strings (i.e. not cell array), convert to cell
elseif ischar(latitude)
    latitude = {latitude};
    longitude = {longitude};

% Verify that both inputs are 1-D arrays of the same length
elseif (length(latitude) ~= length(longitude)) || min(size(latitude)) ~= 1
    error('Both inputs must be 1-D arrays of the same length.')
end

% If inputs are strings, convert to decimal degrees
if ~isnumeric(latitude)
    
    % Creaty empty arrays to hold results
    decLat = nan(length(latitude), 1);
    decLon = nan(length(latitude), 1);
    
    % Cycle through each input
    for i = 1:length(latitude)
        
        % Determine if input is in degrees/minutes/seconds or GPS format by
        % looking for period
        idx = strfind(latitude{i}, '.');
        
        % Parse using spaces
        tempLat = regexp(latitude{i}, ' ', 'split');
        tempLon = regexp(longitude{i}, ' ', 'split');

        % Verify that hemisphere designators are correct
        if ~any(strcmp(tempLat{1}, {'N', 'S'})) || ...
                ~any(strcmp(tempLon{1}, {'E', 'W'}))
            error('Missing hemisphere designator for input given.')
        end
            
        % If no period found, it is in degrees/minute/seconds
        if isempty(idx)
            
            % Verify that both returned 4 results
            if length(tempLat) ~= 4 || length(tempLon) ~= 4
                error('Incorrect format. Please check inputs.')      
            end
            
            % Convert to decimal degrees
            decLat(i) = str2double(tempLat{2}) + ...
                (str2double(tempLat{3}) + str2double(tempLat{4})/60) / 60;
            decLon(i) = str2double(tempLon{2}) + ...
                (str2double(tempLon{3}) + str2double(tempLon{4})/60) / 60;
            
        % If one period found, it is GPS format
        elseif length(idx) == 1
                        
            % Verify that both returned 3 results
            if length(tempLat) ~= 3 || length(tempLon) ~= 3
                error('Incorrect format. Please check inputs.')
            end
            
            % Convert to decimal degrees
            decLat(i) = str2double(tempLat{2}) + str2double(tempLat{3})/60;
            decLon(i) = str2double(tempLon{2}) + str2double(tempLon{3})/60;
            
        % If more than one period found, throw error
        else
            error('Unknown format. Please check inputs.')
        end
        
        % If Southern hemisphere, make negative
        if strcmpi(tempLat{1}, 's')
            decLat(i) = -1 * decLat(i);
        end
        
        % If Western hemisphere, make negative
        if strcmpi(tempLon{1}, 'w')
            decLon(i) = -1 * decLon(i);
        end
    end
    
% Otherwise, if inputs are numeric arrays, store in new variables for
% obtaining depth
else
    decLat = latitude;
    decLon = longitude;
end

% Cycle through each location and obtain depth
depth = nan(length(decLat), 1);
for i = 1:length(decLat)
        
    url = sprintf(['https://www.gmrt.org/services/PointServer/?' ...
        'latitude=%.5f&amp&longitude=%.5f&format=text%2Fplain'], ...
        decLat(i), decLon(i));

    % Encompass urlread with try/catch block, in case Internet goes down
    % and can't retrieve a depth
    try
        
        % Send URL and read resulting depth
        depth(i) = str2double(webread(url));
        
    % If an error occurred, set depth to NaN and carry on
    catch ME
        depth(i) = NaN;
    end
    
    fprintf('%s: Depth at %f, %f = %.2f\n', ...
        datetime('now'), ...
        decLat(i), ...
        decLon(i), ...
        depth(i));
end


function sendAliveMessage(obj)

handles = guidata(obj);

% Send alive message to ER60 object
fwrite(handles.ER60, ['ALI' char(0) ...
    'ClientID:' handles.clientID ...
    ',SeqNo:' int2str(handles.clientSeqNo) ...
    char(0)], 'char');
