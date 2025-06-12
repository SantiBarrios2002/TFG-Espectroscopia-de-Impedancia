<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# AD5940 ESP32 Configuration User Manual

This comprehensive manual provides detailed guidance for configuring your ESP32-AD5940 bioimpedance measurement system, covering all critical parameters and their optimal selection criteria.

## Measurement Configuration Parameters

### **Frequency Sweep Settings**

**Start Frequency Selection**

- **Range**: 0.015 Hz to 200 kHz
- **Low frequencies (0.015-1 Hz)**: Use for electrodermal activity (EDA) and slow biological processes
- **Medium frequencies (1 Hz-10 kHz)**: Optimal for most bioimpedance applications including body composition analysis
- **High frequencies (10 kHz-200 kHz)**: Required for intracellular resistance measurements and fast impedance characterization
- **Recommendation**: Start with 1 Hz for general bioimpedance measurements

**Points Configuration**

- **Typical range**: 10-100 points per decade
- **Linear sweep**: Use fewer points (20-50 total) for speed
- **Logarithmic sweep**: Use more points (50-100 total) for better frequency resolution
- **Trade-off**: More points = better resolution but longer measurement time

**Amplitude Settings**

- **Range**: 10 mV to 600 mV peak-to-peak
- **Safety consideration**: Keep below 10 mV RMS for human subjects
- **Signal quality**: Higher amplitudes improve SNR but may cause non-linear effects
- **Recommendation**: Start with 10 mV RMS (28 mV peak-to-peak) for bioimpedance

**Stop Frequency Selection**

- **Maximum**: 200 kHz (hardware limitation)
- **Practical limit**: 100 kHz for most bioimpedance applications
- **Consider**: Electrode polarization effects increase at higher frequencies
- **Recommendation**: 100 kHz for comprehensive bioimpedance analysis


### **Power Mode Configuration**

**Low Power Mode (<80 kHz)**

- **System clock**: 16 MHz
- **Current consumption**: ~2.2 mA for high speed DAC
- **Use when**: Measurement frequencies below 80 kHz
- **Advantages**: Lower power consumption, suitable for battery operation
- **Register setting**: `PMBW = 0`

**High Power Mode (>80 kHz)**

- **System clock**: 32 MHz
- **Current consumption**: ~4.5 mA for high speed DAC
- **Use when**: Measurement frequencies above 80 kHz
- **Advantages**: Higher bandwidth capability up to 200 kHz
- **Register setting**: `PMBW = 1`


### **Transimpedance Amplifier (TIA) Configuration**

**Capacitance Settings (1, 2, 4, 8, 16, 32 pF)**

- **1-4 pF**: Use for high frequency measurements (>10 kHz)
    - Higher bandwidth but potentially less stable
    - Better for impedance spectroscopy
- **8-16 pF**: Balanced setting for medium frequencies (1-10 kHz)
    - Good compromise between bandwidth and stability
- **32 pF**: Use for low frequency measurements (<1 kHz)
    - Lower bandwidth but maximum stability
    - Recommended for DC measurements

**Selection Formula**: Bandwidth ≈ 1/(2π × RTIA × CTIA)

### **Sample Rate Configuration**

**Available rates**: 200 kSPS (normal mode), 400 kSPS (high speed mode)

- **200 kSPS**: Sufficient for frequencies up to 80 kHz
- **400 kSPS**: Required for frequencies above 80 kHz
- **Nyquist consideration**: Sample rate should be >2× highest frequency component
- **Recommendation**: Use 200 kSPS unless measuring above 80 kHz


### **PGA Gain Selection**

**Available gains**: 1, 1.5, 2, 4, 9

**Selection criteria**:

- **Gain = 1**: Input range ±0.9 V, use for large signals
- **Gain = 1.5**: Input range ±0.9 V, factory calibrated, recommended default
- **Gain = 2**: Input range ±0.6 V, good for medium signals
- **Gain = 4**: Input range ±0.3 V, use for small signals
- **Gain = 9**: Input range ±0.133 V, maximum sensitivity for very small signals

**Selection formula**: Choose gain to maximize ADC input range without saturation
Required gain ≥ (Expected signal amplitude) / (0.9 V)

### **Internal RTIA Selection**

**Available values**: 200 Ω, 1 kΩ, 5 kΩ, 10 kΩ, 20 kΩ, 40 kΩ, 80 kΩ, 160 kΩ

**Selection criteria**:

- **200 Ω-1 kΩ**: High current measurements (>1 mA)
- **1 kΩ-10 kΩ**: Medium current measurements (100 µA - 1 mA)
- **10 kΩ-80 kΩ**: Low current measurements (10 µA - 100 µA)
- **80 kΩ-160 kΩ**: Very low current measurements (<10 µA)

**Selection formula**: RTIA = 0.9 V / Expected_max_current

### **Calibration Resistor Configuration**

**Purpose**: System calibration to remove gain and offset errors
**Value selection**: Choose close to expected impedance range

- **Accuracy requirement**: Use 1% precision resistor with low temperature coefficient
- **Typical values**: 200 Ω, 1 kΩ, 10 kΩ depending on measurement range
- **Connection**: Between RCAL0 and RCAL1 pins


### **Digital Filter Settings**

**Filter Level Options**:

- **None**: No additional filtering, fastest conversion, highest noise
- **1.1**: Sinc2 filter with lower oversampling, faster conversion
- **1.2**: Sinc2 filter with higher oversampling, better noise rejection

**Hanning Window**:

- **Enable**: Recommended for impedance measurements to reduce spectral leakage
- **Disable**: Only for time-domain measurements requiring fast response

**DFT Number Selection (4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384)**:

- **4-16**: Fastest measurements, lowest resolution
- **64-256**: Good balance for most applications
- **1024-2048**: High resolution, recommended for precision measurements
- **4096-16384**: Maximum resolution, slowest measurements

**Trade-off matrix**:


| DFT Number | Measurement Time | Frequency Resolution | Recommended Use |
| :-- | :-- | :-- | :-- |
| 4-16 | Fastest | Lowest | Real-time monitoring |
| 64-256 | Fast | Medium | General measurements |
| 1024-2048 | Medium | High | Precision analysis |
| 4096+ | Slowest | Highest | Research applications |

## Optimization Guidelines

### **Speed Optimization**

1. Use lower DFT numbers (16-256)
2. Disable unnecessary filtering (Filter Level = None)
3. Use single frequency measurements instead of sweeps
4. Select minimum required PGA gain
5. Use low power mode when possible

### **Accuracy Optimization**

1. Enable calibration with appropriate resistor value
2. Use higher DFT numbers (≥1024)
3. Enable Hanning window
4. Select optimal PGA gain to maximize ADC range
5. Use Filter Level 1.2 for noise reduction

### **Noise Optimization**

1. Enable sinc2 filtering (Filter Level 1.2)
2. Use higher DFT numbers
3. Select appropriate TIA capacitance for frequency range
4. Use higher PGA gains when signal permits
5. Ensure proper grounding and shielding

### **Power Optimization**

1. Use low power mode for frequencies <80 kHz
2. Minimize DFT numbers while maintaining required accuracy
3. Use hibernate mode between measurements
4. Disable unused analog blocks
5. Optimize measurement duty cycle

## Application-Specific Recommendations

### **Body Impedance Analysis (BIA)**

- **Frequency range**: 1 kHz - 100 kHz
- **Amplitude**: 10 mV RMS maximum
- **RTIA**: 1 kΩ - 10 kΩ
- **PGA gain**: 1.5 or 2
- **DFT**: 1024-2048
- **Power mode**: Low power


### **Skin Impedance Measurement**

- **Frequency range**: 0.1 Hz - 10 kHz
- **Amplitude**: 5-10 mV RMS
- **RTIA**: 10 kΩ - 80 kΩ
- **PGA gain**: 2 or 4
- **DFT**: 512-1024
- **Power mode**: Low power


### **High-Speed Impedance Spectroscopy**

- **Frequency range**: 1 kHz - 200 kHz
- **Amplitude**: 10-50 mV RMS
- **RTIA**: 1 kΩ - 20 kΩ
- **PGA gain**: 1.5 or 2
- **DFT**: 2048-4096
- **Power mode**: High power (>80 kHz)


## Critical Safety Considerations

### **Human Subject Measurements**

- **Maximum current**: 10 µA RMS through human body
- **Maximum voltage**: 10 mV RMS across electrodes
- **Isolation**: Use isolation capacitors (>100 nF) in series with electrodes
- **Current limiting**: Include series resistance (>1 kΩ) for protection


### **Electrode Configuration**

- **4-wire measurement**: Always use for accurate impedance measurement
- **Excitation electrodes**: CE0 for current injection
- **Measurement electrodes**: AIN1 (current), AIN3-AIN2 (voltage differential)
- **Isolation**: Maintain galvanic isolation from mains power


## Register Configuration Examples

### **Basic Bioimpedance Setup**

```
AFECON = 0x00080E00;     // Enable ADC, DAC, TIA, excitation
PMBW = 0x00000000;       // Low power mode
HSTIACON = 0x00000001;   // VZERO0 as TIA positive input
HSRTIACON = 0x00000003;  // 10 kΩ RTIA, 4 pF capacitor
ADCCON = 0x00008200;     // PGA gain 1.5, normal mode
DFTCON = 0x00000001;     // Enable Hanning window
```


### **High-Frequency Setup (>80 kHz)**

```
AFECON = 0x00080E00;     // Enable ADC, DAC, TIA, excitation
PMBW = 0x00000001;       // High power mode
HSTIACON = 0x00000001;   // VZERO0 as TIA positive input
HSRTIACON = 0x00000001;  // 1 kΩ RTIA, 2 pF capacitor
ADCCON = 0x00008200;     // PGA gain 1.5, high speed mode
DFTCON = 0x00000001;     // Enable Hanning window
```

This manual provides the foundation for optimal AD5940 configuration. Always verify settings through measurement validation and adjust parameters based on your specific application requirements and signal characteristics.

<div style="text-align: center">⁂</div>

[^1]: AD5940.pdf

[^2]: 02_049988b_top.pdf

[^3]: 1-s2.0-S0378775320310466-main.pdf

[^4]: INTLJO-1.PDF

[^5]: sensors-16-00673.pdf

[^6]: Aerospace_Applications_of_Wearable_Bioimpedance_Monitoring.pdf

[^7]: 202001-Electrophoresis-EIS.pdf

[^8]: ADVANC-1.PDF

[^9]: Applications-of-bioelectrical-impedance-analysis-BIA-in-aerospace-medicine.pdf

