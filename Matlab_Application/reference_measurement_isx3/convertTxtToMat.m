function convertTxtToMat()
%CONVERTTXTTOMAT Convert .txt files to .mat format compatible with EIS app
%
% This function processes all .txt files in the reference_measurement_isx3
% directory and converts them to .mat files compatible with the EIS app.
%
% Output .mat file structure:
%   - frequency: frequency points in Hz
%   - impedance_real: real part of impedance in Ohms
%   - impedance_imag: imaginary part of impedance in Ohms
%   - measurement_info: struct with metadata

    % Base directory containing measurement files
    base_dir = pwd;

    % Find all .txt files
    txt_files = dir(fullfile(base_dir, '*.txt'));

    fprintf('Found %d .txt files to convert\n', length(txt_files));

    for i = 1:length(txt_files)
        txt_file = txt_files(i);
        txt_path = fullfile(txt_file.folder, txt_file.name);

        fprintf('Processing: %s\n', txt_path);

        try
            % Parse .txt file
            data = parseTxtFile(txt_path);

            % Create output filename (.mat in same directory)
            [filepath, name, ~] = fileparts(txt_path);
            mat_path = fullfile(filepath, [name '.mat']);

            % Save as .mat file
            frequency = data.frequency;
            impedance_real = data.impedance_real;
            impedance_imag = data.impedance_imag;
            measurement_info = data.measurement_info;

            save(mat_path, 'frequency', 'impedance_real', 'impedance_imag', 'measurement_info');

            fprintf('  -> Saved: %s\n', mat_path);

        catch ME
            fprintf('  ERROR: %s\n', ME.message);
        end
    end

    fprintf('\nConversion complete!\n');
end

function data = parseTxtFile(filename)
%PARSETXTFILE Parse .txt file with frequency,Re,Im format
%
% Returns struct with:
%   - frequency: frequency points in Hz
%   - impedance_real: real part of impedance in Ohms
%   - impedance_imag: imaginary part of impedance in Ohms
%   - measurement_info: metadata struct

    % Read file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Could not open file: %s', filename);
    end

    % Initialize data structure
    data = struct();
    data.frequency = [];
    data.impedance_real = [];
    data.impedance_imag = [];
    data.measurement_info = struct();

    % Extract filename for metadata
    [~, name, ~] = fileparts(filename);
    data.measurement_info.name = name;
    data.measurement_info.source = 'ISX3 Impedance Analyzer';
    data.measurement_info.timestamp = datestr(now);

    % Parse file
    line_count = 0;
    while ~feof(fid)
        line = fgetl(fid);
        line_count = line_count + 1;

        if line_count == 1
            % Header line (frequency[Hz],Re[Ohm],Im[Ohm])
            continue;
        else
            % Data lines with format: frequency,real,imaginary
            % Skip empty lines
            if isempty(strtrim(line))
                continue;
            end

            % Parse frequency,real,imaginary
            values = strsplit(line, ',');
            if length(values) == 3
                freq = str2double(values{1});
                real_part = str2double(values{2});
                imag_part = str2double(values{3});

                % Only add valid data points
                if ~isnan(freq) && ~isnan(real_part) && ~isnan(imag_part)
                    data.frequency(end+1) = freq;
                    data.impedance_real(end+1) = real_part;
                    data.impedance_imag(end+1) = imag_part;
                end
            end
        end
    end

    fclose(fid);

    % Convert to column vectors
    data.frequency = data.frequency(:);
    data.impedance_real = data.impedance_real(:);
    data.impedance_imag = data.impedance_imag(:);

    % Add derived information
    data.measurement_info.num_points = length(data.frequency);
    if ~isempty(data.frequency)
        data.measurement_info.freq_min = min(data.frequency);
        data.measurement_info.freq_max = max(data.frequency);
    else
        data.measurement_info.freq_min = 0;
        data.measurement_info.freq_max = 0;
    end

    fprintf('  Parsed %d data points (%.1f - %.1f Hz)\n', ...
        data.measurement_info.num_points, ...
        data.measurement_info.freq_min, ...
        data.measurement_info.freq_max);
end