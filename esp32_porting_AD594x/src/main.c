#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"

static const char *TAG = "MAIN";

void app_main(void)
{
    ESP_LOGI(TAG, "Starting ESP32 application");
    
    // Your code here
    
    while (1) {
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
}