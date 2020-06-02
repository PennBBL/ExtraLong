### This script creates a csv of flywheel meta data pertaining to scanning
### parameters.
###
### Ellyn Butler
### June 2, 2020


import flywheel
import datetime
import pandas as pd


fw = flywheel.Client()
project = fw.projects.find_first("label=ExtraLong") #project.info says GRMPY

params = {} #keys are bblid, seslabel
problems = []
for ses in project.sessions():
    bblid = ses['info']['BIDS']['Subject']
    seslabel = ses['info']['BIDS']['Label']
    acq = ses.acquisitions()
    if len(acq) < 2:
        metadata = fw.get(acq[0]['_id'])
        metainfo = metadata['files'][0]['info']
        if bblid not in params:
            if 'EchoTime' in metainfo:
                params[bblid] = {}
                params[bblid][seslabel] = {
                    'EchoTime':metainfo['EchoTime'],
                    'RepetitionTime':metainfo['RepetitionTime'],
                    'FlipAngle':metainfo['FlipAngle'],
                    'InPlanePhaseEncodingDirectionDICOM':metainfo['InPlanePhaseEncodingDirectionDICOM'],
                    'ManufacturersModelName':metainfo['ManufacturersModelName'],
                    'ProtocolName':metainfo['ProtocolName'],
                    'ReceiveCoilName':metainfo['ReceiveCoilName'],
                    'SliceThickness':metainfo['SliceThickness']
                }
            else:
                problems.append([bblid, acq[0]['_id']])
    else:
        break

params_data = pd.DataFrame.from_dict(params)
pd.DataFrame.to_csv(params_data, '~/Documents/ExtraLong/data
