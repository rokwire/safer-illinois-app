Pull Request:
this pull request changed ios scanner into an intermittent scanner where the scanner works for at least 4 seconds and pause for 150 seconds and repeat. 

Related change: process exposure is now called every time the scanner is paused or stopped rather than periodically. Ping exposure functionality is gone. Screen lighting is done every time the phone's screen is turned off and the scanner is/starts scanning. 

# Files changed: 
## ExposurePlugin.m
- line 388: startCentral now will pause the scanner after at least 4 seconds 
- line 407 - 452: added temporary start scanning and stop scanning which scans for at least 4 seconds and pause for at least 150 seconds. 
- line 453: added code to clear timer for intermittent scanner and process exposure.
- line 839: changed local notification request logic so that screen will only be lit when scanner is scanning rather than periodically. 
- line 1272: removed ping exposure functionality