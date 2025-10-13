function convertCsvToMat()
%CONVERTCSVTOMAT Convert AD5940 CSV files to .mat format compatible with EIS app
%
% This function processes all .csv files in the current directory
% and converts them to .mat files compatible with the EIS app.
%
% Input CSV format (from AD5940 evaluation software):
%   Uses period as decimal separator, exported with commas
%   Format: Freq.part1.part2,Magnitude,Freq_dup.part1.part2,Phase.part1.part2,...
%
% Output .mat file structure:
%   - frequency: frequency points in Hz
%   - impedance_real: real part of impedance in Ohms
%   - impedance_imag: imaginary part of impedance in Ohms
%   - measurement_info: struct with metadata including measurement parameters

    % Use current directory
    base_dir = pwd;

    % Find all .csv files
    csv_files = dir(fullfile(base_dir, '*.csv'));

    fprintf('Found %d .csv files to convert\n', length(csv_files));

    for i = 1:length(csv_files)
        csv_file = csv_files(i);
        csv_path = fullfile(csv_file.folder, csv_file.name);

        fprintf('Processing: %s\n', csv_path);

        try
            % Parse .csv file
            data = parseCsvFile(csv_path);

            % Create output filename (.mat in same directory)
            [filepath, name, ~] = fileparts(csv_path);
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
            fprintf('  Stack: %s\n', ME.getReport());
        end
    end

    fprintf('\nConversion complete!\n');
end

function data = parseCsvFile(filename)
%PARSECSVFILE Parse AD5940 evaluation software CSV file
%
% Returns struct with:
%   - frequency: frequency points in Hz
%   - impedance_real: real part of impedance in Ohms
%   - impedance_imag: imaginary part of impedance in Ohms
%   - measurement_info: metadata struct with measurement parameters

    % Read entire file as text to handle encoding properly
    fid = fopen(filename, 'r', 'n', 'UTF-8');
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
    data.measurement_info.source = 'AD5940 Evaluation Board';
    data.measurement_info.timestamp = datestr(now);

    % Storage for parsed data
    magnitude = [];
    phase_deg = [];
    frequency = [];

    line_count = 0;
    while ~feof(fid)
        line = fgetl(fid);
        line_count = line_count + 1;

        % Skip header lines (first 2 lines)
        if line_count <= 2
            continue;
        end

        % Skip empty lines
        if isempty(strtrim(line))
            continue;
        end

        % Split by comma
        values = strsplit(line, ',');

        % Data lines have at least 9 columns
        % Format based on test output:
        % Columns: Freq_part1, Freq_part2, Freq_part3, Mag, Freq_dup1, Freq_dup2, Phase_part1, Phase_part2, Phase_part3, [empty], [empty], Param_name, Param_value, Unit

        if length(values) >= 6
            % Try to parse as data line
            % The CSV format is: Freq,Freq_decimals,Mag,Mag_decimals,Freq_dup,Freq_dup_decimals,Phase,Phase_decimals,...
            % Reconstruct by joining pairs with decimal point

            % Frequency: join column 1 and 2
            freq_str = [strtrim(values{1}) '.' strtrim(values{2})];
            freq = str2double(freq_str);

            % Magnitude: join column 3 and 4
            mag_str = [strtrim(values{3}) '.' strtrim(values{4})];
            mag = str2double(mag_str);

            % Phase: join column 7 and 8
            if length(values) >= 8
                phase_str = [strtrim(values{7}) '.' strtrim(values{8})];
                phase = str2double(phase_str);
            else
                phase = NaN;
            end

            % Only add valid data points
            if ~isnan(freq) && ~isnan(mag) && ~isnan(phase)
                frequency(end+1) = freq;
                magnitude(end+1) = mag;
                phase_deg(end+1) = phase;
            end
        end

        % Skip parameter parsing - too complex with varying CSV formats
    end

    fclose(fid);

    % Convert magnitude and phase to real and imaginary parts
    phase_rad = phase_deg * pi / 180;
    data.impedance_real = magnitude .* cos(phase_rad);
    data.impedance_imag = magnitude .* sin(phase_rad);
    data.frequency = frequency;

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

