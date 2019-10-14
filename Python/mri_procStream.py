import os
import re
from time import sleep
from multiprocessing import Process, Queue as MsgQueue, current_process
from datetime import datetime

CPU_COUNT = os.cpu_count()
SLOTS = 0
log = '/dev/null'

def start_job( queue, jnum, cMsgQueue, pMsgQueue, job_dict) :
# {{{        
    def process( mriObj) :
# {{{        
        def get_cmd( instructs) :
# {{{        
            nonlocal outName
            cmd = instructs["command"]
            filename = mriObj.filename
            outName = filename[0:filename.find(".")]
            outName = outName + instructs["suffix"] + \
                    instructs["format"]
            if instructs["command"].count( "%s") == \
                    len( instructs["substitute"]) :
                substs = []
                i = 0
                for subst in instructs["substitute"] :
                    token = eval( subst)
                    if type( token) == list :
                        tmp = ""
                        for num in token :
                            tmp = tmp + str( num) + " "
                        token = tmp
                    substs.append( token)
                    i += 1
                cmd = cmd % tuple( substs)
                return cmd
            else :
                error = "Bad job dict formatation!"
                pMsgQueue.put( [jnum, "ERROR", error])
                current_process().terminate()
# }}}        
        def backup() :
# {{{        
            filename = mriObj.filename
            os.system( "echo 'Worker %d: Backup for %s.' >>%s" %\
                    (jnum, filename , log))
            if not os.path.exists( "./tmp") :
                os.mkdir( "tmp")
            os.rename( filename, "./tmp/" + filename)
            metafile = mriObj.metadata.filename
            tmpMetafile = metafile[0:metafile.find(".")]
            newMetafile = tmpMetafile + instructs["suffix"] + \
                    instructs["format"] + ".meta"
            os.rename( metafile, newMetafile)
            os.system( "echo 'Worker %d: new metafile %s.' >>%s" %\
                    (jnum, newMetafile, log))
            return
# }}}        
        def prepareLog() :
# {{{        
            filename = mriObj.filename
            if filename.find("+") != -1 :
                baseName = filename[0:filename.find("+")]
            else :
                baseName = filename[0:filename.find(".")]
            extension = filename[filename.find("."):]
            fileLog = baseName + extension + ".log"
            if not os.path.exists( "./%s" % fileLog) :
                os.system( "touch %s" % fileLog)
            now = datetime.now().strftime("[%d/%m/%Y-%H:%M:%S]")
            os.system( "echo %s %s >> %s" % (now, cmd, fileLog))
            return fileLog
# }}}        
        path = mriObj.get_path()
        os.system( "echo 'Worker %d: cd to  %s.' >>%s" %\
                (jnum, path, log))
        os.chdir( path)
        instructs = job_dict[mriObj.attribs.sub_type]
        cmd = get_cmd( instructs)
        os.system( "echo 'Worker %d: %s.' >>%s" % \
                (jnum, cmd, log))
        fileLog = prepareLog()
        status = os.system( cmd + " 1>>%s 2>&1" % fileLog )
        check = os.file.ispath( "./" + outName)
        if status != 0 or not check :
            error = "Something went wrong with process command!"
            pMsgQueue.put( [jnum, ERROR, error, mriObj.filename])
            current_process().terminate()
        else :
            status = "DONE"
            backup()
        return status
# }}}        
    os.system( "echo 'Worker %d Spawned.' >>%s" % \
            (jnum, log))
    while True :
        os.system( "echo 'Worker %d: New iteration.' >>%s" % \
                (jnum, log))
        msg = cMsgQueue.get()
        if msg == "Out!" :
            os.system( "echo 'Worker %d: Exit message!.' >>%s"\
                    % (jnum, log))
            break
        else :
            index = msg
            os.system( "echo 'Worker %d: Got job at %d.' >>%s"\
                    % (jnum, index , log))
            status = process( queue.queue[index])
            pMsgQueue.put( [jnum, status, index])
            if status == "DONE" :
                os.system( "echo 'Worker %d: Done index %d!.'\
                        >>%s" % (jnum, index, log))
            else :
                os.system( "echo 'Worker %d: Error at index %d!.'\
                        >>%s" % (jnum, index, log))
    return
# }}}        
def manager( queue, job_queue, pMsgQueue, cMsgQueue) :
# {{{        
    def send_job( worker, next_job) :
# {{{        
        print ( "Sending next job to worker %d, index %d." % \
                ( worker, next_job))
        print ( "\tFilename => %s" % queue.queue[next_job].filename)
        cMsgQueue[worker].put( next_job) 
        working[worker] = True
        next_job += 1
        return next_job
# }}}        
    def wait_worker( pMsgQueue) :
# {{{        
        print( "Waiting for some worker...")
        msg = pMsgQueue.get()
        worker = msg[0]
        status = msg[1]
        if status == "DONE" :
            index = msg[2]
            target = queue.queue[index].filename
            print( "Worker %d: %s done!" % ( worker, target))
            job_queue[index] = True
            working[worker] = False
        elif status == "ERROR" :
            error = msg[2]
            filename = msg[3]
            target = queue.queue[index].filename
            print( "Worker %d: %s failed!" % ( worker, target))
            print( "He leaved a message: %s" % error)
            working[worker] = False
            while any( working) :
                wait_worker( pMsgQueue)
            exit( 1)
        else :
            print( "Undefined error!")
            working[worker] = False
            while any( working) :
                wait_worker( pMsgQueue)
            exit( 255)
        return
# }}}        
    next_job = 0
    working = [False] * len( cMsgQueue)
    while True :
        print( "Job %d/%d." % (next_job + 1, len( job_queue)))  
        if all( working) :
            print ( "All workers doing its things!")
            wait_worker( pMsgQueue)
        elif next_job < len( job_queue) :    
            for i in range( len( working)) :
                if not working[i]: 
                    worker = i
                    break
            next_job = send_job( worker, next_job)
        else :
            print( "All jobs have been alocated! Time for wait.")
            while not all( job_queue) :
                wait_worker( pMsgQueue)
            for i in cMsgQueue :
                i.put( "Out!")
            return job_queue
        
# }}}        
def main( job_dict, multi_queue, observate = False) :
# {{{        
    queue = multi_queue.slots[SLOTS]
    job_queue = [False] * queue.get_size()
    pMsgQueue = MsgQueue()
    cMsgQueue = []
   #pin, cout = os.pipe()
    print( "Prepare to fork!")
    for i in range( CPU_COUNT) :
        childQueue = MsgQueue()
        Process( target = start_job, args = ( queue, i, childQueue, \
                pMsgQueue, job_dict)).start()
        cMsgQueue.append( childQueue)
    job_queue = manager( queue, job_queue, pMsgQueue, cMsgQueue)
    return job_queue
# }}}        
            # job_dict = { 'T1w': job1, 'T2w': job2, 'rest': job3}
            # job_dict["T1w"] = { 'command' :"blablabla in bla out"
            # 'suffix' : "blabla", 'format' : ".nii.gz", }
