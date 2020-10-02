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
import zipfile
import numpy as np


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

outdir = '/Users/butellyn/Documents/ExtraLong/data/freesurferCrossSectional/'
if not os.path.exists(outdir+'fmriprep'):
    os.mkdir(outdir+'fmriprep')
if not os.path.exists(outdir+'freesurfer'):
    os.mkdir(outdir+'freesurfer')


#for subj in subjects:
subj = subjects[0]
sublabel = subj['label']
#if not os.path.exists(fmriprepdir+sublabel):
#    os.mkdir(fmriprepdir+sublabel)
for ses in subj.sessions():
    ses = ses.reload()
    d = get_latest_fmriprep_correctversion(ses, '0.3.4_20.0.5')
    # Get file name
    filename = [s for s in d['job']['saved_files'] if 'fmriprep_sub-' in s][0]
    seslabel = ses['label']
    # Check if the fmriprep and freesurfer dirs are already in the ses dir
    if not os.path.exists(outdir+'fmriprep/'+sublabel+'/'+seslabel):
        d.download_file(filename, outdir+filename)
        # Unzip files
        with zipfile.ZipFile(outdir+filename,"r") as zip_ref:
            zip_ref.extractall(outdir)
        # Get rid of id directory and zip
        iddir = [dI for dI in os.listdir(outdir) if os.path.isdir(os.path.join(outdir, dI))]
        iddir = np.setdiff1d(iddir, ['fmriprep', 'freesurfer'])[0]
        for processeddir in ['fmriprep', 'freesurfer']:
            source = outdir+iddir+'/'+processeddir
            files = os.listdir(source) #######
            notsubdirfiles = []
            for dI in os.listdir(outdir+iddir+'/'+processeddir):
                if os.path.isdir(os.path.join(outdir+iddir+'/'+processeddir, dI)) and 'sub-' in dI:
                    subdir = dI
                else:
                    notsubdirfiles.append(dI)
            # Move contents of session-specific fmriprep dir to a session directory
            # within the fmriprep-created subject directory.
            os.mkdir(source+'/'+subdir+'/'+seslabel)
            for file in notsubdirfiles:
                shutil.move(f"{source}/{file}", outdir+iddir+'/'+processeddir+'/'+sublabel+'/'+seslabel)
            # Move anat and figures into ses dir
            for dI in os.listdir(outdir+iddir+'/'+processeddir+'/'+subdir):
                if not 'ses-' in dI:
                    shutil.move(f"{source}/{dI}", outdir+iddir+'/'+processeddir+'/'+sublabel+'/'+seslabel)
            # Collapse directories
            if processeddir == 'fmriprep':
                # Move this sub*/ses* directory into the fmriprep directory that I
                # created
            else:
                # Move the contents of ses dir into the fmriprep ses dir
            # Delete the directory with the analysis ID as the name
            os.rmdir(source)
        os.remove(outdir+sublabel+'/'+seslabel+'/'+filename)
    if not :
        # Rename fmriprep output to include the session label
        fmriprep_files = os.listdir()
    if not os.path.exists(outdir+sublabel+'/'+seslabel):
        os.mkdir(outdir+sublabel+'/'+seslabel)








# TO DO: Add lines to check if directories and files already exist before creating them




#
