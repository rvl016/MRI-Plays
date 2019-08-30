#!/usr/bin/python3
from dialog import Dialog
import mri_search
import mri_queues
import mri_takeNotes
import mri_procStream

#root_dir = "/home/ravi/HD2TB/Documents/IC/MRI"
ROOT_DIR = "/home/rvl016/Documents/fMRI_data"
EXCLUDE = False
MULTI_QUEUE = False

searchMain = mri_search.main
queuesMain = mri_queues.main
takeNotesMain = mri_takeNotes.main
procStreamMain = mri_procStream.main

d = Dialog()


def makeExcludeRules( excludeRules) :
# {{{    
    restrictions = d.checklist( text = "Select which restrictions " + \
            "do you like:", choices = [("Study", "", 0), \
            ("Subject", "", 0), ("Type", "", 0), ("Sub Type", "", 0),\
            ("Meta Data Status", "", 0)])[1]
    if "Study" in restrictions :
        excludeRules[0] = d.checklist( text = "Choose studies to\
                exclude:",choices = [ ("COBRE", "", 0), \
                ("NMorphCH", "", 0)])[1]
    if "Subject" in restrictions :
        excludeRules[1] = d.inputbox( text = "Type subjects to INCLUDE"\
                + ":\nEach subject must have prefix and be separeted" \
                + " by space characters.", width = 80)[1]
        excludeRules[1] = re.split( r'\ +', excludeRules[1])
       #for i in range(0, len(excludeRules[1]) - 1)
       #   excludeRules[1][i] = "sub-" + excludeRules[1][i]
        excludeRules[1][:] = ["sub-" + i for i in excludeRules[1]] 
    if "Type" in restrictions :
        excludeRules[2] = d.checklist( text = "Choose types to " + \
                "exclude:", choices = [ ("anat", "", 0), \
                ("func", "", 0)])[1]
    if "Sub Type" in restrictions and "anat" in excludeRules[2] :
        excludeRules[3] = d.checklist( text = "Choose subtypes to\
                exclude:", choices = [ ("T1w", "", 0),\
                ("T2w", "", 0)])[1]
    if "Meta Data Status" in restrictions :
        excludeRules[4] = d.checklist( text = "Choose metadata status"\
                + " to exclude:", choices = [ ("0", "Good to go", 0),\
                ("1", "Some problem", 0), ("2", "A lot of problem", 0),\
                ("3", "Unusable", 0)])[1]
    return excludeRules    
# }}} 
def newJobDict( exclusionRules) :
# {{{       
    def create_instructs( subtype) :
# {{{       
        ok = ""
        while ok != "ok" :
            exclusionRules[subtype] = { }
            exclusionRules[subtype]["format"] = _format
            exclusionRules[subtype]["suffix"] = suffix
            exclusionRules[subtype]["command"] = d.inputbox(\
                    text = mainMsg % ( subtype, "%s"), width = 80)[1]
            ok = d.yesno( okMsg % ("Command for " + subtype,\
                    "\n" + exclusionRules[subtype]["command"]))
        return 
# }}}        
    formatMsg = "Choose format for output:"
    choices = [(".nii.gz", ""), (".nii", "")]
    suffixMsg = "Type suffix for output ('+blah'):"
    okMsg = "%s: %s. Is that right?"
    ok = ""
    while ok != "ok" :
        _format = d.menu( formatMsg, choices)[1]
        ok = d.yesno( okMsg % ("Format", _format))
    ok = ""
    while ok != "ok" :
        suffix = d.inputbox( suffixMsg)[1]
        ok = d.yesno( okMsg % ("Suffix", suffix))
    mainMsg = "Type the command for %s subtype:\n"
    mainMsg = mainMsg + "\nUse '%s' to indicate where input and output,"
    mainMsg = mainMsg + " respectively, must be placed."
    if "anat" not in exclusionRules[2] :
        if "T1w" not in exclusionRules[3] : 
            create_instructs( "T1w")           
        if "T2w" not in exclusionRules[3] : 
            create_instructs( "T2w")           
    if "func" not in exclusionRules[2] :
        create_instructs( "rest")           

    return jobDict
# }}}        
class Ready_jobs :

    def __init__( self):


def take_notes() :



def main() :
    mainMsg = "Select what thing you want to do:"
    choices = [("1", "Process"), ("2", "Take session notes"), \
            ("3", "Take notes with comparison"), ("4", "Take notes")]
    workType = d.menu( text = mainMsg, choices = choices)[1]
    workType = int( workType)
    excludeRules = [[],[],[],[],[]]
    if EXCLUDE :
        makeExcludeRules( excludeRules)
    head = searchMain( root_dir, excludeRules)
    multiQueue = queuesMain( head, multi)
    if workType == 1 :
        jobDict = newJobDict( exclusionRules)
        jobQueue = procStreamMain( JobDict, multiQueue)
    elif workType == 2 :
    elif workType == 3 :
    elif workType == 4 :

    else :
    return
        

