# Longitudinal Processing with FreeSurfer 7.1.1

For more information see: 
https://surfer.nmr.mgh.harvard.edu/fswiki/LongitudinalProcessing

## **Workflow for Longitudinal Processing**

### 1. For each _session/timepoint_, cross-sectionally process using default recon-all.

```
  recon-all -s <tpNid> -i path_to_tpN_dcm -all
```
Provide:  
▪ `tpNid`: session_id for time point _N_  
▪ `path_to_tpN_dcm`: path to T1w scan from time point _N_

_This is accomplished by the first script, `run_cross_sectional.sh`_  
<br> 
### 2. For each _subject_, create unbiased template from average of all sessions/time point using -base flag.
```
  recon-all -base <templateid> -tp <tp1id> -tp <tp2id> ... -all
```
Provide:\
    ▪ `templateid`: name of new average template to be created for this subject\
    ▪ `tpNid`: session_id for timepoint _N_. Pass in all tpids 1 ... _N_ for the subject. 

_This is accomplished by the second script, `make_avg_templates.sh`_  
<br>

### 3. For each _session/timepoint_, longitudinally process with respect to the subject's average template using -long flag.
```
  recon-all -long <tpNid> <templateid> -all
```
Provide:  
▪ `tpNid`: session_id for timepoint _N_  
▪ `templateid`: name of average template for the subject, created in previous step.

_This is accomplished by the third script, `run_longitudinal.sh`_

