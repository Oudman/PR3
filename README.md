# PR3
## Project introduction
The PR3 project is one of the research projects done in collaboration with the ESA. This project is about radio interferometry. A rocket sends out four signals at 2MHz, 4MHz, 6MHz and 8MHz, all carried on a higher-frequency signal. At ground level, six ground stations with each three antennas receive these signals. By comparing phase differences of these four signals between the three antennas, a rough estimate of the rocket location can be made. Next, phase differences can be compared between the different ground stations, from which a very accurate position of the rocket can be retrieved. Well, theoretically, after March 2019 we know if shit works. 

## Code scope
A bit more technical. For each antenna, the the carried signal is recovered and converted to a 14 bit digital signal. Each ground station contains one FPGA receiving the digital signals of the three antennas. The FPGA has to extract the four frequencies at 2MHz, 4MHz, 6MHz and 8MHz and extract per frequency the signal phase. These phases are then send to a Linux subsystem on the same ground station, which then stores the data for later analysis. This git project focusses on the FPGA code, with the three incoming digital signals as starting point and the extracted phases as end point.

## Code design
The code contains several modules. Top level module is PR3.sv, responsible for the complete data flow. Data flow can be split in four main steps:

### Input buffer
Input is sampled at 20.48MHz at all three antennas at the same time. Data is stored in three RAM blocks. A total number of 2048 entries per antenna is stored. When the input is completed, the data is output sequentially, with one antenna data block at a time. 
 
### FFT operation
Input is retrieved from the input buffer. An FFT is run over the 2048 entries.

### Carthesian to polar tranformation
The FFT output is tranformed from Carthesian to polar. 

### Peak detection and phase extraction
First, within 1MHz of each peak, the highest peak is stored together with each left and right neighbour bin and its central bin number. Second, per peak an interpolation delta is calculated in order to get the exact peak frequency. Using this delta, two possible phases at this peak location are calculated and output together with the calculated exact frequency.

## Data formats
### Input data
Input data is assumed to be consisting of three 14-bit wide input streams.

### Output data
Output data is streamed in blocks and uses the following format:

* 4 bytes: block number
* Per peak:
	+ 4 bytes: interpolated frequency in Hz
	+ 2 bytes: interpolated phase A + 2 bytes: interpolated phase B
	+ Per raw data bin:
		- 2 bytes: bin magnitude + 2 bytes: bin phase

To calculate the phase in radians, use the following formula:

> (the two input bytes as signed integer) / 2^15 * pi

## Copyrights
Copyright (c) 2018 F.H. Oudman, f.h.oudman@student.tue.nl
