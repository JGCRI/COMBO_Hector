% SCENGEN output extractor
% Takes model output from SCENGEN, clips headers, and allows user to pull
% out the average temperature change in SCENGEN output from a 3x3 box
% surrounding a particular cell of interest (user-defined).

% FILE NAMING CONVENTION REQUIREMENTS:
% All files should be put into a folder clearly labeled with the model
% parameters used to generate the output. A README.txt file should be
% included in this folder with details on the models used.
% Filenames should be formatted as follows: YYYYAAA.OUT
% YYYY = 4-digit year
% AAA = code for scenario (e.g., A1B)
% This version assumes that model output will not be exported at sub-annual
% timescales.

% Compiled by C. Wobus, Stratus Consulting, December 2010

% Note: guts of this code were taken from MathWorks product support at:
% http://www.mathworks.com/support/tech-notes/1400/1402.html
% Front and back end will be used to scan through multiple files and read
% in data from annual, bi-annual, 5-year output, etc.

% Modified 7/12/11 to remove masking of land cells, per experiments run on
% 6/6/11 and email communication from Elizabeth and Jeremy at EPA
% suggesting that land masking is unnecessary.

%clear

%function[temp_CO2,scenarios] = scengen_extractv5(baseT,path1,lat,long);
function[temp_CO2,scenarios] = scengen_extractv5(baseT,path1,path2,path4,...
    path4txt,lat,long);

%Change to file path containing EPA model outputs
cd(path4);

% Bring in 2.5 degree land mask for eliminating land cells from averaging
land1 = dlmread('2p5landmask.txt',',',0,1);
landmask = flipud(land1);

% **********************************************************************
% *********************** CO2 reading routine **************************
% **********************************************************************
% Bring in CO2 concentrations from MAGICC output
% Reads in file concs.up from MAGICC output and formats to fit temperature
% scenarios from corresponding SCENGEN run. Note this file does not change
% throughout the SCENGEN process, so only needs to be run once.

% Changes 3/25/11: EPA customized scenarios use 20 models, whereas previous
% tests used only 9. As a result the header line in the EPA output is an
% extra 

% Read in numeric data from equivalent of MAGICC file 'concs.up'
% NOTE: These files were generated by R. Jones from EPA scenarios; 
% original files at: \\Rjones\EPA_SCENGEN_DATA\EPA_CO2_Concentrations

CO2concs=dlmread('CO2concs.txt','',1,0);

% Export variable CO2output with just year and CO2user columns.
CO2output = CO2concs(:,1:2);

% ************************* END CO2 reading routine *******************

temp_CO2 = [];
scenarios = [];

% create vectors of lats and longs for future lookup
lats = [88.75:-2.5:-88.75]; % These indices are equivalent to rows
longs = [-178.75:2.5:178.75]; % These indices are equivalent to columns

[~,row] = min(abs(lats-lat)); % Returns the row of interest
[~,col] = min(abs(longs-long)); % Returns column of interest

% Land Masking parameters: DISABLED AS OF 7/12/11
% % Find indices of all cells in 3x3 box around cell of interest that
% % contain only ocean (i.e., landmask ==0)
% checkland = landmask(row-1:row+1,col-1:col+1);
% landcells = find(checkland);

% Look through directory to find all SCENGEN output files
outfiles = strcat(path4,'\*.csv');
files = dir(outfiles);
%files = dir('C:\projects\COMBO\Matlab\Scengen_output\*.OUT');
numfiles = size(files,1);

% Loop to open each file and extract data from the cells of interest
for ii = 1:numfiles
    fname = files(ii).name;
    
    % Text read for bringing in SCENGEN output
    % Modifications needed 3/25/11 to account for longer filenames
    fid = fopen(files(ii).name);
    fname = files(ii).name;
    year = str2num(fname(1:4));
    yeartxt = fname(1:4);
    model = path4txt;
    
    % Initialize loop variables
    no_lines = 0;
    max_line = 0;
    ncols = 146;
    
    % Initialize the data to [].
    data = [];
    
%     % Read through header information. This can be discarded.
%     line = fgetl(fid);
%     if ~isstr(line)
%         disp('Warning: file contains no header and no data')
%     end;
%     [data, ncols, ~, nxtindex] = sscanf(line, '%f');
%     
%     while isempty(data)|(nxtindex==1)
%         no_lines = no_lines+1;
%         max_line = max([max_line, length(line)]);
%         % Create unique variable to hold this line of text information.
%         % Store the last-read line in this variable.
%         eval(['line', num2str(no_lines), '=line;']);
%         line = fgetl(fid);
%         if ~isstr(line)
%             disp('Warning: file contains no data')
%             break
%         end;
%         [data, ncols, ~, nxtindex] = sscanf(line, '%f');
%     end % while
    
    data = csvread(files);
    fclose(fid);
    
    % Reshape output into proper number of rows and columns. Final matrix
    % "output" is just the meat of the data, without first column or last
    % column filled with latitude values.
    eval('data = reshape(data, ncols, length(data)/ncols)'';', '');
    % Note that 1st and last columns are latitude values...clip these.
    data_clip = data(:,(2:ncols-1));
    
    % Calculate average temperature change in 3x3 box around cell of
    % interest. Land cells are no longer masked out:
    avg = mean(mean(data_clip(row-1:row+1,col-1:col+1)));
    
    % LAND MASKING DISABLED AS OF 7/12/11
    %    if isempty(landcells)
    % average all cells in 3x3 window if no land is present:
    % avg = mean(mean(data_clip(row-1:row+1,col-1:col+1)));
    %     else
    %         % Eliminate cells within 3x3 window where land is present:
    %         temp_clip = data_clip(row-1:row+1,col-1:col+1);
    %         % replace land cells with zero and average only nonzero elements
    %         temp_clip(landcells)=0;
    %         avg = mean(temp_clip(find(temp_clip)));
    %     end
    
    % Create file temp_CO2, formatted as three-column matrix with year, CO2,
    % and temperature increase for each year.
    actualT = baseT + avg;
    [~,CO2year] = min(abs(year - CO2output(:,1)));
    temp_CO2 = [temp_CO2; year CO2output(CO2year,2) actualT];
    % Also create variable "scenarios" with just incremental T change per
    % year.
    scenarios = [scenarios; year avg];
    
end % end loop through all SCENGEN files


% Change back to original file path
cd(path1)


%************************************************************************

figure(1)
clf
imagesc(data_clip + -9999.*landmask)
caxis([min(min(data_clip)) max(max(data_clip))]);
hold on
plot(col,row,'rs','LineWidth',2) % Plot location of interest on map
xlabel('Longitude (deg)')
ylabel('Latitude (deg)')
title(['Scenario ',model,', Year ',yeartxt,', DeltaT'])
colorbar('location','southoutside')


end
