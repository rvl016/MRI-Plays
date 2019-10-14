#!/usr/bin/python3
from dialog import Dialog
import re
import os
import subprocess
import mri_search
import mri_queues
#import mri_takeNotes
import mri_procStream

ROOT_DIR = "/backup/MRI"
#ROOT_DIR = "/backup/test"
OBSERVATE_DIR = "/home/ravi/Git/MRI-Plays/Bash/"
NOTES_DIR = "/home/ravi/Git/MRI-Plays/Bash/"
#ROOT_DIR = "/home/rvl016/Documents/fMRI_data"

EXCLUDE = True
MULTI_QUEUE = False

searchMain = mri_search.main
queuesMain = mri_queues.main
#takeNotesMain = mri_takeNotes.main
procStreamMain = mri_procStream.main

d = Dialog()

def moveToTrash( path, filename) :
    filePath = os.path.join( path, filename)
    newPath = path.replace( "/MRI/", "/Trash/")
    if not os.path.isdir( newPath) :
        os.makedirs( newPath)
    os.rename( filePath, os.path.join( newPath, filename))

def makeExcludeRules( excludeRules) :
# {{{    
    restrictions = d.checklist( text = "Select which restrictions " + \
            "do you like:", choices = [("Study", "", 0), \
            ("Subject", "", 0), ("Type", "", 0), ("Sub Type", "", 0),\
            ("Meta Data Status", "", 0), ("Echo", "", 0)])[1]
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
        excludeRules[4] = [int( i) for i in excludeRules[4]]
    if "Echo" in restrictions :
        excludeRules[5] = True
    return excludeRules    
# }}} 
def newJobDict( exclusionRules) :
# {{{       
    def create_instructs( subtype) :
# {{{       
        instructs = {}
        ok = ""
        while ok != "ok" :
            instructs = {}
            instructs["format"] = _format
            instructs["suffix"] = suffix
            instructs["command"] = d.inputbox(\
                    text = mainMsg % ( subtype, "%s"), width = 80)[1]
            ok = d.yesno( okMsg % ("Command for " + subtype,\
                    "\n" + instructs["command"]), width = 80)
            substNum = instructs["command"].count("%s")
            if ok == "ok" and substNum < 2 :
                ok = ""
        substs = []
        i = 0
        while i < substNum - 2 :
            substs.append( (str( i + 1), "mriObj.metadata.json."))
            i += 1
        substs.append( (str( i + 1), "filename"))      
        i += 1
        substs.append( (str( i + 1), "outName"))
        while True :
            ok = ""    
            while ok != "ok" :
                out = d.inputmenu( substMsg % instructs["command"], \
                        menu_height = 3 * substNum, choices = substs)
                ok = out[0]
                if ok == "accepted" :
                    ok = "ok"
                if ok == "renamed" :
                    swapNum = int( out[1]) - 1
                    substs[swapNum] = list( substs[swapNum])
                    substs[swapNum][1] = out[2]
                    substs[swapNum] = tuple( substs[swapNum])
            ok = ""    
            instructs["substitute"] = []
            for i in range( substNum) :
                instructs["substitute"].append( substs[i][1])
            ok = d.yesno( okMsg % ("Command for " + subtype, "\n" + \
                    instructs["command"] % tuple( \
                    instructs["substitute"])), width = 80)
            if ok == "ok" : 
                break
        return instructs
# }}}        
    jobDict = {}
    formatMsg = "Choose format for output:"
    choices = [(".nii.gz", ""), (".nii", "")]
    suffixMsg = "Type suffix for output ('+blah'):"
    okMsg = "%s: %s\nIs that right?"
    ok = ""
    while ok != "ok" :
        _format = d.menu( text = formatMsg, choices = choices)[1]
        ok = d.yesno( okMsg % ("Format", _format), width = 80)
    ok = ""
    while ok != "ok" :
        suffix = d.inputbox( suffixMsg)[1]
        ok = d.yesno( okMsg % ("Suffix", suffix), width = 80)
    mainMsg = "Type the command for %s subtype:\n"
    mainMsg = mainMsg + "\nUse '%s' to indicate where variables"
    mainMsg = mainMsg + " must be placed.\nAt least a field for input "
    mainMsg = mainMsg + "file and output file must exist!"
    substMsg = "Which variables must be placed in:\n"
    substMsg = substMsg + "%s ?"
    if "anat" not in exclusionRules[2] :
        if "T1w" not in exclusionRules[3] : 
            jobDict["T1w"] = create_instructs( "T1w")           
        if "T2w" not in exclusionRules[3] : 
            jobDict["T2w"] = create_instructs( "T2w")           
    if "func" not in exclusionRules[2] :
        jobDict["rest"] = create_instructs( "rest")           

    return jobDict
# }}}        
def removeTrash( queue, exclusionRules) :
# {{{    
    for mriObj in queue :
        if mriObj.attribs.echo != None and exclusionRules[5] == True :
            filename = mriObj.filename
            metaFile = mriObj.metadata.filename
            jsonFile = mriObj.metadata.json_file
            path = mriObj.get_path()
            moveToTrash( path, filename)
            moveToTrash( path, mataFile)
            moveToTrash( path, jsonFile)
            pastPath = os.path.join( path, "tmp")
            for pastMriObj in mriObj.past :
                pastFile = pastMriObj.filename
                moveToTrash( pastPath, pastFile)
    return
# }}} 
def undoLast( queue) :
# {{{
    for mriObj in queue :
        filename = mriObj.filename
        if len( mriObj.past) == 0 : 
            print( filename, "- No past!")
            continue
        pastMriObj = mriObj.past[0]
        pastFile = pastMriObj.filename
        metaFile = mriObj.metadata.filename
        newMetaFile = metaFile[0:metaFile.find( "+")] 
        newMetaFile = newMetaFile + metaFile[metaFile.find( "."):]
        path = mriObj.get_path()
        pastPath = pastMriObj.get_path()
        os.chdir( path)
        os.rename( metaFile, newMetaFile)
        moveToTrash( path, filename)
        os.rename( os.path.join( pastPath, pastFile), \
                os.path.join( path, pastFile))
# }}}
#class Ready_jobs :
#    def __init__( selfote" ) ):
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
            ("3", "Take notes with comparison"), ("4", "Take notes"), 
            ("5", "Undo last"), ("6", "Remove Trash")]
    workType = d.menu( text = mainMsg, choices = choices)[1]
    workType = int( workType)
    dirMsg = "Type the root dir for MRI files:"
    rootDir = d.inputbox( text = dirMsg, width = 80, init = ROOT_DIR)[1]
    excludeRules = [[],[],[],[],[],[]]
    if EXCLUDE :
        excludeRules = makeExcludeRules( excludeRules)
    head = searchMain( rootDir, excludeRules)
    if workType == 1 :
        multiQueue = queuesMain( head, "file", excludeRules,\
                MULTI_QUEUE)
        jobDict = newJobDict( excludeRules)
        jobQueue = procStreamMain( jobDict, multiQueue)
        if all( jobQueue) :
            d.infobox( "All jobs done! (%d jobs)" % len( jobQueue))
        else :
            d.infobox( "Something went wrong, not all jobs are done!")
    elif workType == 2 :
        multiQueue = queuesMain( head, "ses", excludeRules, MULTI_QUEUE)
        take_notes( which = "ses")
    elif workType == 3 :
        multiQueue = queuesMain( head, "sub", excludeRules,\
                MULTI_QUEUE, filterDoneNts = True)
        take_notes( which = "file", compare = True,\
                multiQueue = multiQueue)
    elif workType == 4 :
        multiQueue = queuesMain( head, "sub", excludeRules, MULTI_QUEUE)
        take_notes( which = "file", compare = False,\
                multiQueue = multiQueue)
    elif workType == 5 :
        multiQueue = queuesMain( head, "file", excludeRules, MULTI_QUEUE)
        queue = multiQueue.slots[0].queue
        if d.yesno( "==== WARNING ====\n\nAre you sure you want \
                to undo last step?", 10, 30) != "ok" :
            return
        undoLast( queue)
    elif workType == 6 :
        multiQueue = queuesMain( head, "file", excludeRules, MULTI_QUEUE)
        queue = multiQueue.slots[0].queue
        if d.yesno( "==== WARNING ====\n\nAre you sure you want \
                to delete these files?", 10, 30) != "ok" :
            return
        removeTrash( queue, excludeRules)
    return

if __name__ == "__main__" :
    main()
