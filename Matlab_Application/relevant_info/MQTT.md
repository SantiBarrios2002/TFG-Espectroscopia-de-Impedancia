<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# MQTT Protocol Communication Guide for MATLAB

This comprehensive documentation covers all aspects of MQTT protocol communication in MATLAB, providing you with essential functions, best practices, and implementation patterns for your development workflow.

## Core MQTT Functions

### Connection Management

**`mqttclient(brokerAddr, Name=Value)`** - Create MQTT client connected to broker[^1][^2]

- **Supported protocols**: mqtt://, tcp://, ws://, ssl://, wss://
- **Common parameters**: Port, ClientID, Username, Password, CARootCertificate
- **Connection verification**: Use `mqttClient.Connected` property to check status

```matlab
% Basic connection
mqttClient = mqttclient("tcp://broker.hivemq.com");

% Secure connection with authentication
mqttClient = mqttclient("ssl://mqtt3.thingspeak.com", Port=8883, ...
    ClientID="myDevice", Username="user", Password="pass", ...
    CARootCertificate="path/to/cert.crt");
```


### Message Operations

**`subscribe(mqttClient, mqttTopic, Name=Value)`** - Subscribe to MQTT topic[^3]

- **Parameters**: QualityOfService (0, 1, 2), Callback (function handle)
- **Returns**: Table showing Topic, QualityOfService, Callback
- **Wildcards supported**: Single-level (+) and multi-level (\#)

```matlab
% Basic subscription
subscribe(mqttClient, "sensor/temperature");

% With callback function
subscribe(mqttClient, "sensor/data", Callback=@processMessage);

% Wildcard subscription
subscribe(mqttClient, "sensors/+/temperature");  % Single-level
subscribe(mqttClient, "building/#");             % Multi-level
```

**`write(mqttClient, mqttTopic, mqttMsg, Name=Value)`** - Write message to MQTT topic[^4][^5]

- **Parameters**: QualityOfService (0, 1, 2), Retain (true/false)
- **Message format**: String or character vector

```matlab
% Basic publish
write(mqttClient, "sensor/temperature", "25.6");

% With QoS and retain flag
write(mqttClient, "device/status", "online", QualityOfService=1, Retain=true);
```

**`read(mqttClient, Topic=mqttTopic)`** - Read available messages from MQTT topic[^6][^7]

- **Returns**: Timetable with Time, Topic, Data columns
- **Behavior**: Flushes messages after reading (cannot be read again)

```matlab
% Read all messages from all subscribed topics
allMessages = read(mqttClient);

% Read messages from specific topic
tempMessages = read(mqttClient, Topic="sensor/temperature");

% Access message data
if ~isempty(tempMessages)
    latestTemp = tempMessages.Data(end);
end
```

**`peek(mqttClient, Topic=mqttTopic)`** - View most recent message from MQTT topic[^8]

- **Returns**: Timetable with most recent message
- **Behavior**: Does not flush messages (can be viewed multiple times)

```matlab
% Peek at latest message without removing it
latestMsg = peek(mqttClient, Topic="sensor/data");
```

**`flush(mqttClient, Topic=mqttTopic)`** - Clear received MQTT messages[^9]

- **Options**: Clear all messages or messages from specific topic

```matlab
% Clear all messages from all topics
flush(mqttClient);

% Clear messages from specific topic
flush(mqttClient, Topic="sensor/temperature");
```

**`unsubscribe(mqttClient, Topic=mqttTopic)`** - Unsubscribe from MQTT topics[^10]

- **Options**: Unsubscribe from all topics or specific topic
- **Wildcards supported**: Can unsubscribe using wildcard patterns

```matlab
% Unsubscribe from specific topic
unsubscribe(mqttClient, Topic="sensor/temperature");

% Unsubscribe from all topics
unsubscribe(mqttClient);

% Unsubscribe using wildcards
unsubscribe(mqttClient, Topic="sensors/+/temperature");
```


## Quality of Service (QoS) Levels

MQTT provides three QoS levels for message delivery reliability[^11][^12][^13][^14]:

### QoS 0 - At Most Once (Fire and Forget)

- **Delivery**: Best effort, no acknowledgment
- **Use case**: Non-critical data where speed is more important than reliability
- **Network overhead**: Minimal
- **Default setting**: Most MQTT clients use QoS 0 by default


### QoS 1 - At Least Once

- **Delivery**: Guaranteed delivery, potential duplicates
- **Use case**: Important data where occasional duplicates are manageable
- **Network overhead**: Moderate (requires PUBACK)
- **Message storage**: Messages queued on sender until acknowledged


### QoS 2 - Exactly Once

- **Delivery**: Guaranteed delivery exactly once, no duplicates
- **Use case**: Critical data where neither loss nor duplication can be tolerated
- **Network overhead**: Highest (four-step handshake)
- **Performance**: Slowest of all QoS levels

```matlab
% Subscribe with different QoS levels
subscribe(mqttClient, "critical/data", QualityOfService=2);
subscribe(mqttClient, "normal/data", QualityOfService=1);
subscribe(mqttClient, "status/info", QualityOfService=0);

% Publish with QoS
write(mqttClient, "important/alert", "System failure", QualityOfService=1);
```


## Security and SSL/TLS Configuration

### Secure Connection Setup

For production environments, always use encrypted connections[^15][^16][^17][^18]:

```matlab
% Basic SSL connection
mqttClient = mqttclient("ssl://secure.broker.com", Port=8883, ...
    CARootCertificate="ca-cert.pem");

% Mutual authentication with client certificates
mqttClient = mqttclient("ssl://secure.broker.com", Port=8883, ...
    CARootCertificate="ca-cert.pem", ...
    ClientCertificate="client-cert.pem", ...
    ClientKey="client-key.pem");
```


### Certificate Management

- **Root certificates**: Use .pem or .crt extensions
- **Security considerations**: Store certificates in secure, encrypted locations
- **Port configuration**: 8883 for SSL/TLS, 1883 for unencrypted connections


## Advanced Features

### Callback Functions

Implement callback functions for real-time message processing[^19][^20]:

```matlab
function processMessage(topic, data)
    fprintf('Received from %s: %s\n', topic, data);
    
    % Process JSON data
    if startsWith(data, '{')
        try
            msgStruct = jsondecode(data);
            % Process structured data
        catch
            warning('Invalid JSON format');
        end
    end
end

% Subscribe with callback
subscribe(mqttClient, "sensor/+/data", Callback=@processMessage);
```


### Retained Messages

Use retained messages for important state information[^21][^22][^23][^24]:

```matlab
% Publish retained message
write(mqttClient, "device/status", "online", Retain=true);

% New subscribers will immediately receive the last retained message
```


### Last Will and Testament (LWT)

Configure Last Will messages for ungraceful disconnection handling[^25][^26][^27][^28][^29]:

```matlab
% Configure LWT during connection
mqttClient = mqttclient("tcp://broker.example.com", ...
    LastWillTopic="device/status", ...
    LastWillMessage="offline", ...
    LastWillQOS=1, ...
    LastWillRetain=true);
```


### Topic Wildcards

Efficiently subscribe to multiple related topics[^30][^31][^32][^33][^34]:

```matlab
% Single-level wildcard (+)
subscribe(mqttClient, "building/floor1/+/temperature");  % Matches any room
subscribe(mqttClient, "sensors/+/status");               % Matches any sensor

% Multi-level wildcard (#)
subscribe(mqttClient, "building/floor1/#");              % Matches all subtopics
subscribe(mqttClient, "alerts/#");                       % All alert types
```


## JSON Message Handling

Process structured data using JSON format[^35][^36]:

```matlab
% Publishing JSON data
sensorData = struct('temperature', 25.6, 'humidity', 60.2, 'timestamp', datetime('now'));
jsonMsg = jsonencode(sensorData);
write(mqttClient, "sensor/data", jsonMsg);

% Receiving and processing JSON
function handleJsonMessage(topic, data)
    try
        msgStruct = jsondecode(data);
        temp = msgStruct.temperature;
        humidity = msgStruct.humidity;
        
        % Process the structured data
        fprintf('Temperature: %.1f°C, Humidity: %.1f%%\n', temp, humidity);
    catch ME
        warning('Failed to parse JSON: %s', ME.message);
    end
end
```


## Real-Time Data Visualization

Implement real-time plotting with MQTT data streams[^37][^38][^39]:

```matlab
% Real-time plotting setup
figure; hold on;
xlabel('Time'); ylabel('Temperature (°C)');
title('Real-time Temperature Monitoring');

% Subscribe to temperature data
subscribe(mqttClient, "sensor/temperature");

% Data collection arrays
timeData = [];
tempData = [];
startTime = datetime('now');

% Real-time update loop
while true
    msgs = read(mqttClient, Topic="sensor/temperature");
    
    if ~isempty(msgs)
        currentTime = seconds(datetime('now') - startTime);
        newTemp = str2double(msgs.Data(end));
        
        % Update data arrays
        timeData(end+1) = currentTime;
        tempData(end+1) = newTemp;
        
        % Update plot
        plot(timeData, tempData, 'b-', 'LineWidth', 2);
        drawnow;
    end
    
    pause(0.1); % Small delay to prevent excessive CPU usage
end
```


## Error Handling and Best Practices

### Connection Management

```matlab
% Check connection status
if ~mqttClient.Connected
    warning('MQTT client disconnected');
    % Implement reconnection logic
end

% Graceful cleanup
try
    unsubscribe(mqttClient);  % Unsubscribe from all topics
    clear mqttClient;         % Clean up client object
catch ME
    warning('Cleanup failed: %s', ME.message);
end
```


### Message Processing

```matlab
% Robust message handling
function safeMessageHandler(topic, data)
    try
        % Your message processing logic here
        processIncomingData(topic, data);
    catch ME
        fprintf('Error processing message from %s: %s\n', topic, ME.message);
        % Log error or implement fallback behavior
    end
end
```


### Common Configuration Issues

- **Port selection**: Use 1883 for unencrypted, 8883 for SSL/TLS connections
- **Certificate paths**: Ensure certificate files are accessible and properly formatted
- **Broker compatibility**: Verify broker supports desired QoS levels and features
- **Network timeouts**: Configure appropriate timeout values for your network conditions


## Performance Optimization

### Message Batching

```matlab
% Collect multiple readings before publishing
readings = [];
for i = 1:10
    readings(end+1) = getCurrentReading();
end

% Publish batch as JSON array
batchMsg = jsonencode(readings);
write(mqttClient, "sensor/batch", batchMsg);
```


### Efficient Subscription Management

```matlab
% Use wildcards to reduce subscription overhead
subscribe(mqttClient, "building/+/sensors/+");  % Instead of individual subscriptions

% Unsubscribe from unused topics
unsubscribe(mqttClient, Topic="old/unused/topic");
```


### Memory Management

```matlab
% Regularly flush old messages to prevent memory buildup
if mod(messageCount, 100) == 0
    flush(mqttClient);
end
```


## Common Patterns and Examples

### Device Status Monitoring

```matlab
% Monitor device connectivity
subscribe(mqttClient, "devices/+/status", Callback=@deviceStatusHandler);

function deviceStatusHandler(topic, data)
    deviceId = extractBetween(topic, "devices/", "/status");
    fprintf('Device %s is now %s\n', deviceId{1}, data);
end
```


### Data Aggregation

```matlab
% Collect data from multiple sensors
sensorData = containers.Map();

function aggregateData(topic, data)
    sensorId = extractAfter(topic, "sensors/");
    sensorData(sensorId) = str2double(data);
    
    % Process when all sensors have reported
    if sensorData.Count >= expectedSensorCount
        processAggregatedData(sensorData);
        sensorData.clear();
    end
end
```


### Command and Control

```matlab
% Send commands to devices
function sendCommand(deviceId, command, parameters)
    cmdStruct = struct('command', command, 'params', parameters);
    cmdJson = jsonencode(cmdStruct);
    write(mqttClient, sprintf("devices/%s/commands", deviceId), cmdJson);
end

% Usage
sendCommand("thermostat01", "setTemperature", struct('target', 22));
```

This documentation provides a complete reference for implementing MQTT communication in your MATLAB applications. Use it as your go-to resource for function syntax, best practices, and implementation patterns.

<div style="text-align: center">⁂</div>

[^1]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.html

[^2]: https://fr.mathworks.com/help/icomm/ug/icomm.mqtt.client.html

[^3]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.subscribe.html

[^4]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.write.html

[^5]: https://ww2.mathworks.cn/help/icomm/ug/icomm.mqtt.client.write.html

[^6]: https://la.mathworks.com/help/icomm/ug/icomm.mqtt.client.read.html

[^7]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.read.html

[^8]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.peek.html

[^9]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.flush.html

[^10]: https://www.mathworks.com/help/icomm/ug/icomm.mqtt.client.unsubscribe.html

[^11]: https://www.mathworks.com/help/simulink/supportpkg/raspberrypi_ug/publish-and-subscribe-to-mqtt-messages.html

[^12]: http://www.steves-internet-guide.com/mqtt-which-qos-to-use/

[^13]: https://thingsboard.io/docs/mqtt-broker/user-guide/qos/

[^14]: https://dev.to/emqx/introduction-to-mqtt-qos-0-1-2-oba

[^15]: https://www.mathworks.com/help/coder/nvidia/ref/mqtt.html

[^16]: https://www.codementor.io/@emqtech/fortifying-mqtt-communication-security-with-ssl-tls-264re3zsxa

[^17]: https://de.mathworks.com/help/icomm/ug/icomm.mqtt.client.html

[^18]: https://www.mathworks.com/help/simulink/supportpkg/raspberrypi_ref/mqtt.html

[^19]: https://www.mathworks.com/help/icomm/ug/subscribe-to-an-mqtt-topic-with-a-callback-function.html

[^20]: https://kr.mathworks.com/help/icomm/ug/subscribe-to-an-mqtt-topic-with-a-callback-function.html

[^21]: https://www.codementor.io/@emqtech/the-beginner-s-guide-to-mqtt-retained-messages-1yz2qmhmb3

[^22]: https://dev.to/emqx/the-beginners-guide-to-mqtt-retained-messages-2no3

[^23]: https://www.emqx.com/en/blog/mqtt5-features-retain-message

[^24]: https://dzone.com/articles/the-beginners-guide-to-mqtt-retained-messages

[^25]: https://www.youtube.com/watch?v=dNy9GEXngoE

[^26]: https://www.ibm.com/docs/en/ibm-mq/9.2?topic=concepts-last-will-testament-publication

[^27]: https://cedalo.com/blog/mqtt-last-will-explained-and-example/

[^28]: https://thingsboard.io/docs/mqtt-broker/user-guide/last-will/

[^29]: https://www.hivemq.com/blog/mqtt-essentials-part-9-last-will-and-testament/

[^30]: https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/

[^31]: https://www.mathworks.com/help/icomm/ug/subscribe-to-an-mqtt-wildcard-topic.html

[^32]: https://www.mathworks.com/help/simulink/supportpkg/android_ug/publish-and-subscribe-to-mqtt-messages.html

[^33]: https://dzone.com/articles/understanding-mqtt-topics-and-wildcards-by-case

[^34]: https://dev.to/hivemq_/mqtt-topics-wildcards-best-practices-part-5-87g

[^35]: https://gist.github.com/fisherds/cad2c1b70f6fccc0357fe51e70bad14a

[^36]: https://stackoverflow.com/questions/23947779/how-to-send-data-as-json-objects-over-to-mqtt-broker/23949871

[^37]: https://highvoltages.co/iot-internet-of-things/mqtt/mqtt-in-matlab/

[^38]: https://peerdh.com/blogs/programming-insights/real-time-data-integration-using-mqtt-for-matlab-visualizations-1

[^39]: https://highvoltages.co/tag/matlab-real-time-plot/

[^40]: https://es.mathworks.com/help/releases/R2024b/icomm/mqtt.html?s_tid=CRUX_topnav

[^41]: https://www.mathworks.com/help/thingspeak/use-desktop-mqtt-client-to-publish-to-a-channel.html

[^42]: https://www.mathworks.com/help/icomm/ug/get-data-from-subscribed-topics-in-mqtt-client.html

[^43]: https://www.mathworks.com/help/simulink/supportpkg/raspberrypi_ref/publish-and-subscribe-to-mqtt-messages.html

[^44]: https://www.mathworks.com/help/icomm/ug/get-started-with-mqtt.html

[^45]: https://www.youtube.com/watch?v=ptdNuqGuf6E

[^46]: https://www.mathworks.com/help/icomm/ug/communicate-securely-thingspeak-mqtt.html

[^47]: https://www.mathworks.com/help/icomm/mqtt.html

[^48]: https://la.mathworks.com/help/icomm/ug/get-started-with-mqtt.html

[^49]: https://github.com/HighVoltages/MQTT-in-MATLAB

[^50]: https://www.mathworks.com/help/simulink/supportpkg/raspberrypi_ref/publish-and-subscribe-to-messages-using-mqtt-blocks.html

[^51]: https://in.mathworks.com/matlabcentral/answers/2078971-sending-all-fields-data-with-mqtt

[^52]: https://www.mathworks.com/help/ecoder/stmicroelectronicsstm32f4discovery/ug/publish-and-subscribe-to-mqtt-messages.html

[^53]: https://es.mathworks.com/matlabcentral/answers/776642-mqtt-mosquitto-publish-and-subscribe

[^54]: https://stackoverflow.com/questions/63997685/nodejs-mqtt-unsubscribe-is-not-a-function

[^55]: https://www.mathworks.com/matlabcentral/answers/461718-mqtt-toolbox-in-matlab-unable-to-process-all-mqtt-messages

[^56]: https://es.mathworks.com/matlabcentral/answers/798712-callback-function-of-subscribe-mqtt-message

[^57]: https://stackoverflow.com/questions/41290359/ssl-in-mqtt-using-mosquitto-broker

[^58]: https://www.hivemq.com/blog/mqtt-essentials-part-4-mqtt-publish-subscribe-unsubscribe/

[^59]: https://es.mathworks.com/matlabcentral/answers/718815-mqtt-algorithm-for-iot

[^60]: https://www.mathworks.com/matlabcentral/discussions/thingspeak/837534-matlab-communication-with-thingsboard-to-read-data

[^61]: https://blogs.mathworks.com/loren/2007/04/30/a-little-bit-on-message-handling/?from=cn

[^62]: https://es.mathworks.com/matlabcentral/answers/1698150-how-do-i-write-to-a-mqtt-topic-through-a-callback-function-from-subscribe

[^63]: https://stackoverflow.com/questions/73223558/simulink-fatal-error-mqttasync-h-no-such-file-or-directory

[^64]: https://www.mathworks.com/help/thingspeak/troubleshoot-MQTT-publish.html

[^65]: https://www.youtube.com/watch?v=hvhtJORsE5Y

[^66]: https://www.mathworks.com/help/thingspeak/troubleshoot-MQTT-subscribe.html

[^67]: https://www.youtube.com/watch?v=sX9iJ6eT9CQ

[^68]: https://www.mathworks.com/help/ecoder/stmicroelectronicsstm32f4discovery/ref/mqttsubscribe.html

[^69]: https://www.mathworks.com/help/coder/nvidia/ug/publish-and-subscribe-to-mqtt-messages.html

[^70]: https://dzone.com/articles/the-beginners-guide-to-mqtt-retained-messages?fromrel=true

[^71]: https://www.cloudamqp.com/blog/mqtt-retained-messages.html

[^72]: https://stackoverflow.com/questions/29786606/about-the-usage-of-the-last-will-and-testament-message-in-mqtt

[^73]: https://www.mathworks.com/matlabcentral/answers/627563-mqtt-publish-from-simulink-model-to-mosquitto-broker

[^74]: https://es.mathworks.com/matlabcentral/answers/1929610-to-receive-data-in-the-matlab-using-mqtt-protocol

[^75]: https://www.reddit.com/r/MQTT/comments/11sl9nt/to_receive_data_in_the_matlab_using_mqtt_protocol/

[^76]: https://www.mathworks.com/help/thingspeak/mqtt-basics.html

[^77]: https://www.mathworks.com/help/icomm/ug/industrial-process-monitoring-using-mqtt-client-blocks-simulink.html

[^78]: https://github.com/gnotomista/mqtt_matlab_interface

[^79]: https://ch.mathworks.com/solutions/internet-of-things.html

[^80]: https://www.mathworks.com/matlabcentral/answers/414355-thingsspeak-and-json-mqtt-messages

