"""
Pydantic schemas for MATLAB integration endpoints
"""
from typing import List, Optional, Dict, Any, Union
from datetime import datetime
from pydantic import BaseModel, Field, validator

class ImpedanceDataPoint(BaseModel):
    """Single impedance measurement data point"""
    frequency: float = Field(..., description="Frequency in Hz")
    impedance_real: float = Field(..., description="Real part of impedance (Ohms)")
    impedance_imag: float = Field(..., description="Imaginary part of impedance (Ohms)")
    phase: Optional[float] = Field(None, description="Phase angle in degrees")
    magnitude: Optional[float] = Field(None, description="Impedance magnitude (Ohms)")
    timestamp: Optional[datetime] = Field(None, description="Measurement timestamp")

class ImpedanceSweep(BaseModel):
    """Complete impedance frequency sweep"""
    device_id: str = Field(..., description="ESP32 device identifier")
    measurement_id: Optional[str] = Field(None, description="Unique measurement identifier")
    start_frequency: float = Field(..., description="Start frequency (Hz)")
    end_frequency: float = Field(..., description="End frequency (Hz)")
    num_points: int = Field(..., description="Number of frequency points")
    sweep_type: str = Field("logarithmic", description="Sweep type: linear or logarithmic")
    excitation_voltage: float = Field(..., description="Excitation voltage (mV)")
    dc_bias: float = Field(0.0, description="DC bias voltage (V)")
    data_points: List[ImpedanceDataPoint] = Field(..., description="Measurement data points")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")
    created_at: Optional[datetime] = Field(None, description="Measurement creation time")

class MatlabDataRequest(BaseModel):
    """Request for downloading data to MATLAB"""
    device_id: str = Field(..., description="Device identifier")
    start_time: Optional[datetime] = Field(None, description="Start time filter")
    end_time: Optional[datetime] = Field(None, description="End time filter")
    measurement_types: Optional[List[str]] = Field(None, description="Filter by measurement types")
    format: str = Field("json", description="Data format: json, csv, or mat")
    include_metadata: bool = Field(True, description="Include measurement metadata")

class MatlabDataResponse(BaseModel):
    """Response for MATLAB data download"""
    device_id: str
    total_measurements: int
    data_format: str
    download_url: Optional[str] = None
    data: Optional[Union[List[ImpedanceSweep], str]] = None
    metadata: Dict[str, Any]

class CircuitModelFit(BaseModel):
    """Circuit model fitting parameters"""
    model_type: str = Field(..., description="Circuit model type (e.g., 'Randles', 'RC')")
    parameters: Dict[str, float] = Field(..., description="Fitted parameter values")
    parameter_errors: Optional[Dict[str, float]] = Field(None, description="Parameter fit errors")
    goodness_of_fit: Optional[float] = Field(None, description="R-squared or chi-squared value")
    frequency_range: Optional[List[float]] = Field(None, description="Frequency range used for fitting")

class MatlabCommandRequest(BaseModel):
    """Request to send command to ESP32 device via MATLAB"""
    device_id: str = Field(..., description="Target device identifier")
    command: str = Field(..., description="Command to execute")
    parameters: Optional[Dict[str, Any]] = Field(None, description="Command parameters")
    timeout: Optional[int] = Field(30, description="Command timeout in seconds")

class MatlabCommandResponse(BaseModel):
    """Response from ESP32 device command"""
    device_id: str
    command: str
    status: str = Field(..., description="Command status: success, error, timeout")
    response: Optional[str] = Field(None, description="Device response")
    execution_time: Optional[float] = Field(None, description="Execution time in seconds")
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class DeviceConfiguration(BaseModel):
    """ESP32 device configuration for impedance measurements"""
    device_id: str
    measurement_settings: Dict[str, Any] = Field(..., description="Measurement parameters")
    calibration_data: Optional[Dict[str, Any]] = Field(None, description="Calibration parameters")
    sample_rate: Optional[float] = Field(None, description="Sample rate (Hz)")
    updated_at: Optional[datetime] = Field(None, description="Configuration update time")

class MatlabSession(BaseModel):
    """MATLAB session information"""
    session_id: str = Field(..., description="Unique session identifier")
    user_id: str = Field(..., description="User identifier")
    connected_devices: List[str] = Field(default_factory=list, description="Connected device IDs")
    active_measurements: List[str] = Field(default_factory=list, description="Active measurement IDs")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_activity: datetime = Field(default_factory=datetime.utcnow)

class DataExportRequest(BaseModel):
    """Request for exporting measurement data"""
    measurement_ids: List[str] = Field(..., description="Measurement IDs to export")
    export_format: str = Field("matlab", description="Export format: matlab, csv, excel")
    include_analysis: bool = Field(False, description="Include analysis results")
    compression: bool = Field(False, description="Compress exported data")

    @validator('export_format')
    def validate_export_format(cls, v):
        allowed_formats = ['matlab', 'csv', 'excel', 'json']
        if v not in allowed_formats:
            raise ValueError(f'Export format must be one of: {allowed_formats}')
        return v

class DataExportResponse(BaseModel):
    """Response for data export request"""
    export_id: str = Field(..., description="Unique export identifier")
    status: str = Field(..., description="Export status")
    file_url: Optional[str] = Field(None, description="Download URL when ready")
    file_size: Optional[int] = Field(None, description="File size in bytes")
    expires_at: Optional[datetime] = Field(None, description="Download link expiration")
    created_at: datetime = Field(default_factory=datetime.utcnow)