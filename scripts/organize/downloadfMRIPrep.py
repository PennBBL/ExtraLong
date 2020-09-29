# # Moving Data to New Project
# 3 Important rules to using the SDK:
# 1. Remember the data model: everything is either an object, or an attachment to an object.
# 2. Objects are nested hierarchically.
# 3. Operating on objects is different from operating on their attachments.


import subprocess as sub
import os
import flywheel
import json
import shutil
import re
import time
import pandas as pd
import pytz
import datetime


fw = flywheel.Client()
proj = fw.lookup('bbl/ExtraLong')
subjects = proj.subjects()


# This function loops through the analyses of a session, checks if `fmriprep`
# ran successfully, and returns the most recent successful `fmriprep` analysis.
def get_latest_fmriprep_correctversion(session, fmriprepVersion):
    if session.analyses:
        timezone = pytz.timezone("UTC")
        init_date = datetime.datetime(2018, 1, 1)
        latest_date = timezone.localize(init_date)
        latest_run = None

        for analysis in session.analyses:
            gear_name = analysis.gear_info['name']
            state = analysis.job.state
            date = analysis.created
            anal = analysis.label
            if 'fmriprep' in gear_name and date > latest_date and state =='complete' and fmriprepVersion in anal:
                latest_date = date
                latest_run = analysis
        if latest_run is not None:
            return(latest_run)
        else:
            return None
    else:
        return None

fmriprepdir = '/Users/butellyn/Documents/ExtraLong/data/freesurferCrossSectional/fmriprepdir/'
#for subj in subjects:
subj = subjects[0]
sublabel = subj['label']
os.mkdir(fmriprepdir+sublabel)
for ses in subj.sessions():
    ses = ses.reload()
    d = get_latest_fmriprep_correctversion(ses, '0.3.4_20.0.5')
    # Get file name
    filename = [s for s in d['job']['saved_files'] if 'fmriprep_sub-' in s][0]
    seslabel = ses['label']
    os.mkdir(fmriprepdir+sublabel+'/'+seslabel)
    d.download_file(filename, fmriprepdir+sublabel+'/'+seslabel+'/'+filename)
















#
