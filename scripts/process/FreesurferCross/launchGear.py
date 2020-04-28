### Launch freesurfer longitudinal gear to CUBIC
###
### Ellyn Butler
### April 22, 2020 - April 27, 2020

import flywheel
import datetime


fw = flywheel.Client()
project = fw.projects.find_first("label=ExtraLong") #project.info says GRMPY

now = datetime.datetime.now().strftime("%Y-%m-%d_%H:%M")

fmriprep = fw.lookup('gears/fmriprep-hpc/0.3.4_20.0.5') # Latest version as of April 27, 2020

analysis_label = 'FreesurferCross_{}_{}_{}'.format(now, fmriprep.gear.name,
    fmriprep.gear.version)

inputs = {"freesurfer_license": project.files[0]}
fs_data = inputs['freesurfer_license'].read().decode() #May be a problem

config_anatonly_cross = {'longitudinal': False, 'anat_only': True,
    'FREESURFER_LICENSE': fs_data, 'bold2t1w_dof': 6}
    # April 10, 2020: last argument only necessary because there is currently an error in the manifest

analysis_ids = []
fails = []
sessions_to_run = project.sessions()

sessions_to_run = sessions_to_run[1:200] #0:200

for ses in sessions_to_run:
    try:
        _id = fmriprep.run(analysis_label=analysis_label,
            config=config_anatonly_cross, inputs=inputs, destination=ses)
        analysis_ids.append(_id)
    except Exception as e:
        print(e)
        fails.append(ses)

jobs = fw.jobs.find('state=pending,gear_info.name="fmriprep-hpc",destination.type="analysis"', limit=50)

for job in fw.jobs.iter_find('state=pending'):
    print('Job: {}, Gear: {}'.format(job.id, job.gear_info.name))
