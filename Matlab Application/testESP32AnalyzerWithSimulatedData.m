% Example usage of the DatasetGenerator for testing
function testESP32AnalyzerWithSimulatedData()
    % Create dataset generator
    generator = DatasetGenerator('Duration', 60, 'SampleRate', 10, 'NoiseLevel', 0.02);
    
    % Generate different types of test data
    fprintf('Generating test datasets...\n');
    
    % RC Charging curve
    [time1, voltage1] = generator.generateRCCharging(1000, 100e-6, 5.0);
    
    % Double RC for more complex fitting
    [time2, voltage2] = generator.generateDoubleRC(1000, 100e-6, 5000, 20e-6, 5.0);
    
    % Battery discharge curve
    [time3, voltage3] = generator.generateBatteryDischarge(2.0, 0.1, 3.7);
    
    % Save datasets for later use
    save('test_datasets.mat', 'time1', 'voltage1', 'time2', 'voltage2', 'time3', 'voltage3');
    
    % Display demonstration
    DatasetGenerator.demonstrateDatasets();
    
    fprintf('Test datasets generated and saved to test_datasets.mat\n');
    fprintf('You can now use these datasets in simulation mode of the ESP32 Data Analyzer\n');
end
