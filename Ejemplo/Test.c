#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "Test_SPI.h"
#include "Impedance.h"
#include "ad5940.h"

#define APPBUFF_SIZE 512
uint32_t AppBuff[APPBUFF_SIZE];

int32_t ImpedanceShowResult(uint32_t *pData, uint32_t DataCount)
{
  float freq;
  fImpPol_Type *pImp = (fImpPol_Type*)pData;
  AppIMPCtrl(IMPCTRL_GETFREQ, &freq);

  printf("Freq:%.2f ", freq);
  /* Procesa los datos */
  for(int i = 0; i < DataCount; i++)
  {
    printf("RzMag: %f Ohm , RzPhase: %f \n", pImp[i].Magnitude, pImp[i].Phase * 180 / MATH_PI);
  }
  return 0;
}

static int32_t AD5940PlatformCfg(void)
{
  CLKCfg_Type clk_cfg;
  FIFOCfg_Type fifo_cfg;
  AGPIOCfg_Type gpio_cfg;

  /* Restablece hardware */
  AD5940_HWReset();
  AD5940_Initialize();

  /* Configuración de la plataforma */
  /* Paso 1. Configurar el reloj */
  clk_cfg.ADCClkDiv = ADCCLKDIV_1;
  clk_cfg.ADCCLkSrc = ADCCLKSRC_HFOSC;
  clk_cfg.SysClkDiv = SYSCLKDIV_1;
  clk_cfg.SysClkSrc = SYSCLKSRC_HFOSC;
  clk_cfg.HfOSC32MHzMode = bFALSE;
  clk_cfg.HFOSCEn = bTRUE;
  clk_cfg.HFXTALEn = bFALSE;
  clk_cfg.LFOSCEn = bTRUE;
  AD5940_CLKCfg(&clk_cfg);

  /* Paso 2. Configuración de FIFO y Secuenciador */
  fifo_cfg.FIFOEn = bFALSE;
  fifo_cfg.FIFOMode = FIFOMODE_FIFO;
  fifo_cfg.FIFOSize = FIFOSIZE_4KB; /* 4kB para FIFO */
  fifo_cfg.FIFOSrc = FIFOSRC_DFT;
  fifo_cfg.FIFOThresh = 4;  /* Resultado DFT */
  AD5940_FIFOCfg(&fifo_cfg);
  fifo_cfg.FIFOEn = bTRUE;
  AD5940_FIFOCfg(&fifo_cfg);

  /* Paso 3. Configurar el controlador de interrupciones */
  AD5940_INTCCfg(AFEINTC_1, AFEINTSRC_ALLINT, bTRUE);  /* Habilita todas las interrupciones */
  AD5940_INTCClrFlag(AFEINTSRC_ALLINT);
  AD5940_INTCCfg(AFEINTC_0, AFEINTSRC_DATAFIFOTHRESH, bTRUE);
  AD5940_INTCClrFlag(AFEINTSRC_ALLINT);

  /* Paso 4: Reconfigura GPIO */
  gpio_cfg.FuncSet = GP0_INT | GP1_SLEEP | GP2_SYNC;
  gpio_cfg.InputEnSet = 0;
  gpio_cfg.OutputEnSet = AGPIO_Pin0 | AGPIO_Pin1 | AGPIO_Pin2;
  gpio_cfg.OutVal = 0;
  gpio_cfg.PullEnSet = 0;
  AD5940_AGPIOCfg(&gpio_cfg);
  AD5940_SleepKeyCtrlS(SLPKEY_UNLOCK);  /* Permite que AFE entre en modo de reposo */

  return 0;
}

void AD5940ImpedanceStructInit(void)
{
  AppIMPCfg_Type *pImpedanceCfg;

  AppIMPGetCfg(&pImpedanceCfg);
  /* Paso 1: Configurar la información de la secuencia de inicialización */
  pImpedanceCfg->SeqStartAddr = 0;
  pImpedanceCfg->MaxSeqLen = 512;

  // Configurar la amplitud de la señal de excitación (600 mV pico a pico)
  pImpedanceCfg->DacVoltPP = 600.0f;  // Establecer la amplitud deseada
  pImpedanceCfg->BiasVolt = 1200.0f;  // Establecer DC bias deseado


  pImpedanceCfg->RcalVal = 10000.0;
  pImpedanceCfg->SinFreq = 10000.0;
  pImpedanceCfg->FifoThresh = 4;

  /* Establecer la matriz de interruptores */
  
  /*
  pImpedanceCfg->DswitchSel = SWD_CE0;
  pImpedanceCfg->PswitchSel = SWP_RE0;
  pImpedanceCfg->NswitchSel = SWN_SE0;
  pImpedanceCfg->TswitchSel = SWT_SE0LOAD;
  */

  //pImpedanceCfg->HstiaRtiaSel = HSTIARTIA_5K;
  pImpedanceCfg->HstiaRtiaSel = HSTIARTIA_1K; //Internal RTIA Selection
  pImpedanceCfg->HstiaCtia = 32.0f; /* onfigurar Ctia en 32 pF */

  /* Configurar la función de barrido */
  pImpedanceCfg->SweepCfg.SweepEn = bTRUE; /* Habilita el barrido */
  pImpedanceCfg->SweepCfg.SweepStart = 100e2f; /* Comienza desde 10kHz */
  pImpedanceCfg->SweepCfg.SweepStop = 100e2f;   /* Detiene en 10kHz */
  pImpedanceCfg->SweepCfg.SweepPoints = 5;    /* Puntos del barrido */
  //pImpedanceCfg->SweepCfg.SweepLog = bTRUE; /* Barrido Logarítmico ON (Logarithmic) */
  pImpedanceCfg->SweepCfg.SweepLog = bFALSE; /* Barrido Logarítmico OFF (Logarithmic) */

  /* Modo de potencia */
  //pImpedanceCfg->PwrMod = AFEPWR_HP; /* HIGH POWER */
  pImpedanceCfg->PwrMod = AFEPWR_LP; /* LOW POWER */
  
  //pImpedanceCfg->ADCSinc3Osr = ADCSINC3OSR_2; /* Sample rate de 400kSPS */
  /* Sample rate de 10SPS */
  pImpedanceCfg->ADCSinc3Osr = ADCSINC3OSR_2;
  pImpedanceCfg->ADCSinc2Osr = ADCSINC2OSR_800;

  pImpedanceCfg->DftNum = DFTNUM_8192; /* Número de puntos DFT */
  pImpedanceCfg->DftSrc = DFTSRC_SINC3;

  /* GAIN */
  pImpedanceCfg->AdcPgaGain = 1; // Selección de ganancia 1, que equivale a GNPGA_1
}

void AD5940_Main(void)
{
  uint32_t temp; 
  uint32_t sweepCount = 0;  // Contador de barridos 
  AppIMPCfg_Type *pImpedanceCfg;

  AppIMPGetCfg(&pImpedanceCfg);  // Asegúrate de obtener la configuración de impedancia

  AD5940PlatformCfg();  /* Configura la plataforma */
  AD5940ImpedanceStructInit();  /* Inicializa los parámetros de impedancia */
  
  AppIMPInit(AppBuff, APPBUFF_SIZE); /* Inicializa la aplicación IMP */
  AppIMPCtrl(IMPCTRL_START, 0);  /* Inicia la medición de impedancia */
 
  while(sweepCount < pImpedanceCfg->SweepCfg.SweepPoints)
  {
    if(AD5940_GetMCUIntFlag())
    {
      AD5940_ClrMCUIntFlag();
      temp = APPBUFF_SIZE;
      AppIMPISR(AppBuff, &temp);  /* Procesa los datos */
      ImpedanceShowResult(AppBuff, temp);  /* Muestra los resultados */

      sweepCount++;  // Incrementa el contador de barridos
    }
  }
}

/* Función app_main que inicializa FreeRTOS y las tareas */
void app_main(void)
{
  /* Inicializar AD5940 */
  initialize_ad5940();
  validate_ad5940_id();
  //validate_ad5940_write(); // Llamada a la prueba de escritura

  /* Inicializa el sistema de medidas */
  AD5940_Main();  /* Llama a la función que contiene la lógica principal */
}