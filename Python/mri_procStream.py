import os
import re
from time import sleep
from multiprocessing import Process, Queue as MsgQueue, current_process

CPU_COUNT = os.cpu_count()
SLOTS = 0
pts = 1

def start_job( queue, jnum, cMsgQueue, pMsgQueue, job_dict) :
# {{{        
    def process( mriObj) :
# {{{        
        def get_cmd( instructs) :
# {{{        
            cmd = instructs["command"]
            filename = mriObj.filename
            out_name = filename[0:filename.find(".")]
            out_name = out_name + instructs["suffix"] + \
                    instructs["format"]
            if instructs["command"].count( "%s") == 2 :
                cmd = cmd % ( filename, out_name)
#           if re.search( r'\b IN \b', cmd) and \
#                   re.search( r'\b OUT \b', cmd) :
#               cmd = re.sub( r'\b IN \b', filename, cmd)
#               cmd = re.sub( r'\b OUT \b', out_name, cmd)
                return cmd
            else :
                error = "Bad job dict formatation!"
                pMsgQueue.put( [jnum, "ERROR", error])
                current_process().terminate()
# }}}        
        def backup() :
# {{{        
            os.system( "echo 'Worker %d: Backup for %s.' >/dev/pts/%d" %\
                    (jnum, mriObj.filename , pts))
            path = mriObj.get_path()
            os.chdir( path)
            os.system( "echo 'Worker %d: cd to  %s.' >/dev/pts/%d" %\
                    (jnum, path, pts))
           #if not os.path.exists( "./tmp") :
           #    os.mkdir( "tmp")
           #os.rename( filename, "./tmp/" + filename)
            metafile = mriObj.metadata.filename
            tmpMetaName = metafile[0:metafile.find(".")]
           #os.rename( metafile, tmpMetaName + \
           #        instructs["suffix"] + instructs["format"] + ".meta")
            n = tmpMetaName+instructs["suffix"]+instructs["format"] + ".meta"
            os.system( "echo 'Worker %d: new metafile  %s.' >/dev/pts/%d" %\
                    (jnum, n, pts))
            return
# }}}        
        path = mriObj.get_path()
        os.chdir( path)
        instructs = job_dict[mriObj.attribs.sub_type]
        cmd = get_cmd( instructs)
        os.system( "echo 'Worker %d: %s.' >/dev/pts/%d" % \
                (jnum, cmd, pts))
        sleep( 5)
       #status = os.system( cmd)
       #if status != 0 :
       #    error = "Something went wrong with process command!"
       #    pMsgQueue.put( [jnum, ERROR, error, mriObj.filename])
       #    current_process().terminate()
       #else :
       #    status = "DONE"
        status = "DONE"
        backup()
        return status
# }}}        
   #cin = os.fdopen( cin)
    os.system( "echo 'Worker %d Spawned.' >/dev/pts/%d" % \
            (jnum, pts))
    while True :
        os.system( "echo 'Worker %d: New iteration.' >/dev/pts/%d" % \
                (jnum, pts))
        msg = cMsgQueue.get()
        if msg == "Out!" :
            os.system( "echo 'Worker %d: Exit message!.' >/dev/pts/%d" %\
                    (jnum, pts))
            break
        else :
            index = msg
            os.system( "echo 'Worker %d: Got job at %d.' >/dev/pts/%d" % \
                    (jnum, index , pts))
            status = process( queue.queue[index])
            pMsgQueue.put( [jnum, status, index])
    current_process().terminate()
# }}}        
def manager( multi_queue, job_queue, pMsgQueue, cMsgQueue) :
# {{{        
    def send_job( worker, next_job) :
# {{{        
        print ( "Sending next job to worker %d, index %d." % \
                ( worker, next_job))
        cMsgQueue[worker].put( next_job) 
        working[worker] = True
        next_job += 1
        return next_job
# }}}        
    def wait_worker( pMsgQueue) :
# {{{        
        print( "Waiting for some worker...")
        msg = pMsgQueue.get()
        print( "Message:", msg)
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
        return 0
# }}}        
    next_job = 0
    working = [False] * len( cMsgQueue)
    while True :
        if all( job_queue) :
            print ( "All done!")
            for i in cMsgQueue :
                i.put( "Out!")
            return job_queue
        elif all( working) :
            print ( "All workers doing its things!")
            wait_worker( pMsgQueue)
        elif next_job < len( job_queue) :    
            for i in range( len( working)) :
                if not working[i]: 
                    worker = i
                    break
            next_job = send_job( worker, next_job)
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
    print( "I think it works!")
    job_queue = manager( queue, job_queue, pMsgQueue, cMsgQueue)
    return job_queue
# }}}        
            # job_dict = { 'T1w': job1, 'T2w': job2, 'rest': job3}
            # job_dict["T1w"] = { 'command' :"blablabla in bla out"
            # 'suffix' : "blabla", 'format' : ".nii.gz", }
