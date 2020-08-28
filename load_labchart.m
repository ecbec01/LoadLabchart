function [restructured_data, varargout] = load_labchart(varargin)
    % Description:
    %
    %     Load a mat file exported from LabChart and restructure it into a
    %     better format, easier to work with.
    %
    % Syntax:
    %
    %     restructured_data = load_labchart()
    %     restructured_data = load_labchart(file_path)
    %     [restructured_data, original_data] = load_labchart()
    %     [restructured_data, original_data] = load_labchart(file_path)
    %
    % Inputs:
    %
    %     file_path  - [ 1 x N ] (char) - File to load
    %
    % Outputs:
    %
    %     restructured_data  - [ M X N ] (table) - LabChart data restructured
    %     original_data      - [ 1 x 1 ] (struct) - LabChart data as exported
    %
    % Details:
    %
    %     Import a mat file exported from LabChart. The file need to be exported
    %     using the standard format and the 32-bit option. Empty channels or
    %     blocks may raise errors.
    %
    % TODO:
    %
    %     - Add more documentation details, such as how data is stored inside
    %       tables and structures
    %     - Refactor code lines containing hardcoded information
    %     - Add support to other export settings from LabChart
    %     - Add logging to console capacity
    %     - Add multiple-file support
    %     - Add support to empty channels/blocks
    %     - Add support to different settings between blocks/channels
    %     - Add error checkings
    %
    % Author:
    %
    %     Eric Becman
    %

    % Get file path
    switch nargin
        case 0
            [file_name, folder_path] = uigetfile('*.mat', 'Select a MAT-file');
            file_path = fullfile(folder_path, file_name);
        case 1
            file_path = varargin{1};
        otherwise
            error('Wrong number of input arguments')
    end

    % Load labchart file
    file = load(file_path);

    % Set function's constants
    PREFIX_NAMES_BLOCKS = 'block_';
    RATES_UNITS = 'Hz';
    COMMENT_TYPES = {'comment', 'event'};
    COMMENT_INFO = {'channel' 'block' 'position' 'type' 'text'};

    % Get file metadata
    [num_channels, num_blocks] = size(file.datastart);
    names_channels = cellstr(file.titles);
    names_blocks = num2cell(1:num_blocks);
    names_blocks = cellfun(@num2str, names_blocks, 'UniformOutput', false);
    names_blocks = strcat(PREFIX_NAMES_BLOCKS, names_blocks);
    units = num2cell(file.unittextmap);
    units = cellfun(@(x) cellstr(file.unittext(x,:)), units);
    sample_rates = file.samplerate;
    tick_rates = file.tickrate;
    min_ranges = file.rangemin;
    max_ranges = file.rangemax;

    % Get comments and events
    comments = array2table(file.com, 'VariableNames', COMMENT_INFO);
    for i = [1, 2, 4, 5]  % Columns to convert from double to cell
        comments.(COMMENT_INFO{i}) = num2cell(comments{:, i});
    end
    for i = 1:height(comments)
        if comments{i, 1}{:} == -1  % Comments placed in all channels
            comments{i, 1}{:} = '';
        else
            comments{i, 1}{:} = names_channels{comments{i, 1}{:}};
        end
        comments{i, 2}{:} = names_blocks{comments{i, 2}{:}};
        comments{i, 4}{:} = COMMENT_TYPES{comments{i, 4}{:}};
        comments{i, 5} = cellstr(file.comtext(comments{i, 5}{:}, :));
    end

    % Initialize table to hold restructured data
    data_table = array2table(cell(num_channels, num_blocks));
    data_table.Properties.RowNames = names_channels;
    data_table.Properties.VariableNames = names_blocks;

    % Restructure file data
    for cha = 1:num_channels
        for blo = 1:num_blocks

            % Initialize structure to hold individual channel-block data
            data_structure = struct;

            % Get time series
            start_point = file.datastart(cha, blo);
            end_point = file.dataend(cha, blo);
            data = file.data(start_point:end_point)';
            tick_rate = tick_rates(blo);
            data_structure.data = timetable(data, 'SamplingRate', tick_rate);
            data_structure.data.Properties.VariableNames = {'Values'};
            data_structure.data.Properties.VariableUnits = units(cha, blo);

            % Get metadata
            data_structure.unit = units{cha, blo};
            data_structure.sample_rate = sample_rates(cha, blo);
            data_structure.sample_rate_unit = RATES_UNITS;
            data_structure.tick_rate = tick_rates(blo);
            data_structure.tick_rate_unit = RATES_UNITS;
            data_structure.range = [min_ranges(cha, blo) max_ranges(cha, blo)];

            % Get comments
            is_global = strcmp(comments{:, 1}, '');
            is_channel = strcmp(comments{:, 1}, names_channels{cha});
            is_block = strcmp(comments{:, 2}, names_blocks{blo});
            selected_comments = is_block & (is_channel | is_global);
            data_structure.comments = comments(selected_comments, :);

            % Sort fields
            fields = fieldnames(data_structure);
            data_structure = orderfields(data_structure, sort(fields));

            % Store structure
            data_table{cha, blo} = {data_structure};

        end
    end

    % Return output
    restructured_data = data_table;
    original_data = file;
    if nargout <= 2
        varargout{1} = original_data;
    else
        error('Wrong number of output arguments');
    end

end
