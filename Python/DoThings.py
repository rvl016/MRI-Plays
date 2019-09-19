#!/usr/bin/python3
from dialog import Dialog
import re
import os
import subprocess
import mri_search
import mri_queues
#import mri_takeNotes
import mri_procStream

ROOT_DIR = "/home/ravi/HD2TB/Documents/IC/MRI"
OBSERVATE_DIR = "/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash/"
NOTES_DIR = "/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash/"
#ROOT_DIR = "/home/rvl016/Documents/fMRI_data"

EXCLUDE = False
MULTI_QUEUE = False

searchMain = mri_search.main
queuesMain = mri_queues.main
#takeNotesMain = mri_takeNotes.main
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
            jobDict[subtype] = {}
            jobDict[subtype]["format"] = _format
            jobDict[subtype]["suffix"] = suffix
            jobDict[subtype]["command"] = d.inputbox(\
                    text = mainMsg % ( subtype, "%s"), width = 80)[1]
            ok = d.yesno( okMsg % ("Command for " + subtype,\
                    "\n" + jobDict[subtype]["command"]))
        return 
# }}}        
    jobDict = {}
    formatMsg = "Choose format for output:"
    choices = [(".nii.gz", ""), (".nii", "")]
    suffixMsg = "Type suffix for output ('+blah'):"
    okMsg = "%s: %s\nIs that right?"
    ok = ""
    while ok != "ok" :
        _format = d.menu( text = formatMsg, choices = choices)[1]
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
#class Ready_jobs :
#    def __init__( self):
def take_notes( which, compare, multiQueue) :
# {{{        
    if which == "file" :
        cmd = OBSERVATE_DIR + "observate.sh" + " file %s %d %s"
        for queue in multiQueue.slots :
            # Obtendo endereço do subject
            if queue.get_size() == 0 : continue
            path = queue.queue[0].get_path()
            path = re.split( r'/', path)
            path = '/'.join( path[0:len(path) - 2]) 
            files = ""
            while not queue.is_empty() :
                mriFile = queue.pop()
                files = files + mriFile.filename + " "
            subprocess.call( cmd % (path, compare, files), shell = True)
        return
    elif which == "ses" :
        path = queue[0].get_path()
        path = re.split( r'/', path)
        path = '/'.join( path[0:len(path) - 2]) 
        cmd = OBSERVATE_DIR + take_notes.sh + "-t ses -d %s"
        # TERMINAR
# }}}        
def main() :
    mainMsg = "Select what thing you want to do:"
    choices = [("1", "Process"), ("2", "Take session notes"), \
            ("3", "Take notes with comparison"), ("4", "Take notes")]
    workType = d.menu( text = mainMsg, choices = choices)[1]
    workType = int( workType)
    dirMsg = "Type the root dir for MRI files:"
    rootDir = d.inputbox( text = dirMsg, width = 80, init = ROOT_DIR)[1]
   #excludeRules = [["NMorphCH"],["sub-A00000300"],["func"],[],[]]
    excludeRules = [[],[],[],[],[]]
    if EXCLUDE :
        excludeRules = makeExcludeRules( excludeRules)
    head = searchMain( rootDir, excludeRules)
    if workType == 1 :
        multiQueue = queuesMain( head, "file", excludeRules,\
                MULTI_QUEUE)
        jobDict = newJobDict( excludeRules)
       #jobQueue = procStreamMain( JobDict, multiQueue)
    elif workType == 2 :
        multiQueue = queuesMain( head, "ses", excludeRules, MULTI_QUEUE)
        take_notes( which = "ses")
    elif workType == 3 :
        multiQueue = queuesMain( head, "sub", excludeRules, MULTI_QUEUE)
        take_notes( which = "file", compare = True,\
                multiQueue = multiQueue)
    elif workType == 4 :
        multiQueue = queuesMain( head, "sub", excludeRules, MULTI_QUEUE)
        take_notes( which = "file", compare = False,\
                multiQueue = multiQueue)
    return

#if __name__ == "__main__" :
#    main()
