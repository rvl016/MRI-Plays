#!/usr/bin/python3
from dialog import Dialog
from datetime import datetime
import re
import os
import subprocess
import mri_search
from mri_search import MRI_File
import mri_queues
#import mri_takeNotes
import mri_procStream
import mri_heuristics

ROOT_BASE = "MRI"
ROOT_DIR = "/home/ravi/HD2TB/Documents/IC/MRI_24_01/MRI"
#ROOT_DIR = "/mnt/usb/CoregTest"
OBSERVATE_DIR = "/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash/"
#OBSERVATE_DIR = "/home/ravi/Git/MRI-Plays/Bash/"
NOTES_DIR = "/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash/"
#NOTES_DIR = "/home/ravi/Git/MRI-Plays/Bash/"

EXCLUDE = True
MULTI_QUEUE = False

searchMain = mri_search.main
queuesMain = mri_queues.main
#takeNotesMain = mri_takeNotes.main
procStreamMain = mri_procStream.main

d = Dialog()

def moveToTrash( path, filename) :
# {{{
    filePath = os.path.join( path, filename)
    newPath = path.replace( "/" + ROOT_BASE + "/", "/Trash/")
    if not os.path.isdir( newPath) :
        os.makedirs( newPath)
    os.rename( filePath, os.path.join( newPath, filename))
# }}}
def makeExcludeRules( excludeRules) :
# {{{    
    restrictions = d.checklist( text = "Select which restrictions " + \
            "do you like:", choices = [("Study", "", 0), \
            ("Subject", "", 0), ("Type", "", 0), ("Sub Type", "", 0),\
            ("Meta Data Status", "", 0), ("Echo", "", 0), \
            ("Flag", "", 0), ("Comment", "", 0)])[1]
    if "Study" in restrictions :
        excludeRules[0] = d.checklist( text = "Choose studies to\
                exclude:",choices = [ ("COBRE", "", 0), \
                ("NMorphCH", "", 0)])[1]
    if "Subject" in restrictions :
        filename = d.inputbox( text = "Type file with subjects" \
                + " to INCLUDE" \
                + ":\nEach subject must have prefix and be separeted" \
                + " by new line characters.", width = 80, init = \
                (0, "/mnt/usb/MRI/filter"))[1]
        excludeRules[1] = []
        with open( filename, "r") as fd :
            line = fd.readline()
            while line :
                excludeRules[1].append( line.replace( " ", "")[:-1])
                line = fd.readline()
        fd.close()
    if "Type" in restrictions :
        excludeRules[2] = d.checklist( text = "Choose types to " + \
                "exclude:", choices = [ ("anat", "", 0), \
                ("func", "", 0)])[1]
    if "Sub Type" in restrictions :
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
    if "Flag" in restrictions :
        flags = d.inputbox( text = "Type a boolean of flags " \
                + "for files:\n", width = 80)[1]
        excludeRules[6] = flags
#       flags = re.split( r' +', flags)
#       for flag in flags :
#           if flag == '' : 
#               continue
#           if flag[0] == '^' :
#               excludeRules[6]['false'].append( flag[1:])
#           else :
#               excludeRules[6]['true'].append( flag)
    if "Comment" in restrictions :
        comments = d.inputbox( text = "Type a boolean of comments " \
                + "for files:\n", width = 80)[1]
        excludeRules[7] = comments
#       comments = re.split( r' +', comments)
#       for comment in comments :
#           if comment == '' : 
#               continue
#           if comment[0] == '^' :
#               excludeRules[7]['false'].append( comment[1:])
#           else :
#               excludeRules[7]['true'].append( comment)
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
            instructs["command"] = d.inputbox( \
                    text = mainMsg % ( subtype, "%s"), width = 80)[1]
            ok = d.yesno( okMsg % ("Command for " + subtype, \
                    "\n" + instructs["command"]), width = 80)
            substNum = instructs["command"].count( "%s")
            instructs["filename"] = d.inputbox( \
                    text = fileMsg, width = 80)[1]
            if ok == 'ok' : 
                if d.yesno( auxMsg, width = 80) == 'ok' :
                    instructs["aux"] = True
                else :
                    instructs["aux"] = False
                if d.yesno( backupMsg, width = 80) == 'ok' :
                    instructs["backup"] = True
                else :
                    instructs["backup"] = False
            if substNum < 2 :
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
    backupMsg = "Do backup? This moves old file to ./tmp/" + \
            "and updates notes filename."
    auxMsg = "Generate auxilliary file? This moves new file to ./aux/"
    fileMsg = "Type the object with input filename:"
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
       #print( filename)
       #continue
        if len( mriObj.past) == 0 : 
            print( filename, "- No past!")
            continue
        flags = []
        for pastObj in mriObj.past :
            if len( pastObj.flags) >= len( flags) :
                flags = pastObj.flags
                pastMriObj = pastObj
        pastFile = pastMriObj.filename
        metaFile = mriObj.metadata.filename
        newMetaFile = pastFile + ".meta"
        path = mriObj.get_path()
        pastPath = pastMriObj.get_path()
        os.chdir( path)
        os.rename( metaFile, newMetaFile)
        moveToTrash( path, filename)
        os.rename( os.path.join( pastPath, pastFile), \
                os.path.join( path, pastFile))
        logFile = mriObj.metadata.logFile
        cmd = "Undo last step: %s -> %s" % ( filename, pastFile)
        if not os.path.exists( "./%s" % logFile) :
            os.system( "touch %s" % logFile)
        now = datetime.now().strftime("[%d/%m/%Y-%H:%M:%S]")
        os.system( "echo '%s %s' >> %s" % (now, cmd, logFile))
        print( filename, "->", pastFile)
    return
# }}}
def findBoolean( boolean, head, by, excludeRules, output) :
# {{{
    def dfsR( ptr, mriObjs) :
# {{{
        if isinstance( ptr, MRI_File) :
            if excludeRules[6] != '' and not eval( excludeRules[6]) :
                return
            mriObjs.append( ptr)
            return
        for child in ptr.child :
            dfsR( child, mriObjs)
        return
# }}}
    if not output == 'stdout' :
        fd = open( output, 'w') 
    if by == 'subject' or by == 'file' :
        root = head.subject
    elif by == 'session' :
        root = head.session
    for ptr in root :
        ptrd = ptr
        mriObjs = []
        dfsR( ptr, mriObjs)
        if len( mriObjs) == 0 : 
            print( "%s hasn't any file for testing!" % ptr.attrib)
            continue
        if by == 'file' :
            for mriObj in mriObjs :
                if eval( boolean) :
                   #if fd in locals() :
                   #    fd.write( "%s\n" % mriObj.filename)
                    print( mriObj.filename)
        else :
            if eval( boolean) :
                if by == 'session' :
                    if fd in locals() :
                        fd.write( "%s\n" % ptr.parent.attrib)
                    print( "%s" % ptr.parent.attrib)
                else :
                    if fd in locals() :
                        fd.write( "%s\n" % ptr.attrib)
                    print( "%s" % ptr.attrib)
                for mriObj in mriObjs :
                    print( "|-", mriObj.filename)
   #if fd in locals() :
   #    fd.close()
# }}}
def take_notes( which, compare, multiQueue, targWhat, compareWhat, \
        filterDoneNts) :
# {{{        
    if not compare : 
        compareWhat = None
    if which == "file" :
        cmd = OBSERVATE_DIR + "observate.sh" + " file %s %d %s %s"
        i = 0
        lenght = 0
        for queue in multiQueue.slots :
            for mriObj in queue.queue :
                lenght += 1
        for queue in multiQueue.slots :
            # Obtendo endereço do subject
            if queue.get_size() == 0 : 
                continue
            ptr = queue.queue[0].parent
            while ptr.level != "subject" :
                ptr = ptr.parent
            path = ptr.get_path() + '/' + ptr.attrib
            files = ""
            progress = str( lenght - i)
            while not queue.is_empty() :
                mriObj = queue.pop()
                targThing = eval( targWhat)
                if filterDoneNts and not targThing.pendingMeta() :
                    i += 1
                    continue
                targName = targThing.filename
                files += (targName + " ")
                if compare :
                    compareName = eval( compareWhat)
                   #compareThing = eval( compareWhat)
                   #compareName = compareThing.filename
                    files += (compareName + " ")
                i += 1
            if files == "" :
                continue
            subprocess.call( cmd % (path, compare, progress, files), \
                    shell = True)
        return
    elif which == "ses" :
        path = queue[0].get_path()
        path = re.split( r'/', path)
        path = '/'.join( path[0:len(path) - 2]) 
        cmd = OBSERVATE_DIR + take_notes.sh + " -t ses -d %s"
        # TERMINAR
# }}}        
def main() :
    mainMsg = "Select what thing you want to do:"
    choices = [("1", "Process"), ("2", "Take session notes"), 
            ("3", "Take notes with comparison"), ("4", "Take notes"), 
            ("5", "Undo last"), ("6", "Remove Trash"), 
            ("7", "Find by boolean"), ("8", "Execute function")]
    workType = d.menu( text = mainMsg, choices = choices)[1]
    workType = int( workType)
    dirMsg = "Type the root dir for MRI files:"
    rootDir = d.inputbox( text = dirMsg, width = 80, init = ROOT_DIR)[1]
    excludeRules = [[],[],[],[],[],[],'','']
    if EXCLUDE :
        excludeRules = makeExcludeRules( excludeRules)
    head = searchMain( rootDir, excludeRules)
    if workType == 1 :
        queue = queuesMain( head, "file", excludeRules,\
                MULTI_QUEUE).slots[0]
        jobDict = newJobDict( excludeRules)
        jobQueue = procStreamMain( jobDict, queue)
        if all( jobQueue) :
            d.infobox( "All jobs done! (%d jobs)" % len( jobQueue))
        else :
            d.infobox( "Something went wrong, not all jobs are done!")
    elif workType == 2 :
        multiQueue = queuesMain( head, "ses", excludeRules, MULTI_QUEUE)
        take_notes( which = "ses")
    elif workType == 3 or workType == 4 :
        compare = 0
        filterDoneNts = False
        if workType == 3 :
            compare = 1
            if d.yesno( "Compare with overlay?", 10, 30) == "ok" :
                compare = 2
        if d.yesno( "Skip done notes?", 10, 30) == "ok" :
            filterDoneNts = True
        targMsg = "Type target object:"
        targWhat = d.inputbox( text = targMsg, init = 'mriObj',\
                width = 80)[1]
        compareMsg = "Type object for comparison:"
        compareWhat = d.inputbox( text = compareMsg, width = 80)[1]
        multiQueue = queuesMain( head, "sub", excludeRules, \
                MULTI_QUEUE)
        take_notes( "file", compare, multiQueue, targWhat, \
                compareWhat, filterDoneNts)
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
    elif workType == 7 :
        byMsg = "Select root level for finding"
        by = d.menu( text = byMsg, choices = [("subject", "1"), 
           ("session", "2"), ("file", "3")])[1]
        boolMsg = "Type boolean for %s:" % by
        boolean = d.inputbox( text = boolMsg, width = 80)[1]
        outMsg = "Type where the output must be (stdout for terminal):"
       #output = d.inputbox( text = outMsg, width = 80, init = (0, \
       #        "/mnt/usb/MRI/filter"))[1]
        output = 'stdout'
        findBoolean( boolean, head, by, excludeRules, output)
    elif workType == 8 :
        funcMsg = "Type function name to run:"
        func = d.inputbox( text = funcMsg, width = 80)[1]
        exec( func)
    return 0

if __name__ == "__main__" :
    main()
