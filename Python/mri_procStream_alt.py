import os
import re
from time import sleep
from multiprocessing import Process, Queue as MsgQueue, current_process

CPU_COUNT = os.cpu_count()
SLOTS = 0
pts = 1

def start_job( queue, jnum, cin, cout, job_dict) :
# {{{        
    def process( targ_ref) :
# {{{        
        def get_cmd( instructs) :
# {{{        
            cmd = instructs["command"]
            filename = targ_ref.filename
            out_name = targ_name[0:targ_name.find(".")]
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
                error = "ERROR Bad job dict formatation!"
                cout.write( "%d %d\n" % (jnum, error))
                os._exit( 127)
# }}}        
        def backup() :
# {{{        
            os.system( "echo 'Worker %d: Backup for %s.' >/dev/pts/%d" %\
                    (jnum, targ_ref.filename , pts))
            path = targ_ref.get_path()
            os.chdir( path)
            os.system( "echo 'Worker %d: cd to  %s.' >/dev/pts/%d" %\
                    (jnum, path, pts))
           #if not os.path.exists( "./tmp") :
           #    os.mkdir( "tmp")
           #os.rename( filename, "./tmp/" + filename)
           #metafile = targ_ref.metadata.filename
           #tmpMetaName = metafile[0:metafile.find(".")]
           #os.rename( metafile, tmpMetaName + \
           #        instructs["suffix"] + instructs["format"] + ".meta")
            n = tmpMetaName+instructs["suffix"]+instructs["format"] + ".meta"
            os.system( "echo 'Worker %d: new metafile  %s.' >/dev/pts/%d" %\
                    (jnum, n, pts))
            return
# }}}        
        path = targ_ref.get_path()
        os.chdir( path)
        instructs = job_dict[targ_ref.attribs.sub_type]
        cmd = get_cmd( instructs)
        os.system( "echo 'Worker %d: %s.' >/dev/pts/%d" % \
                (jnum, cmd, pts))
        sleep( 5)
       #status = os.system( cmd)
       #if status != 0 :
       #    error = "ERROR Something went wrong with process command!"
       #    cout.write( "%d %s\n" % (jnum, error))
       #    os._exit( 127)
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
        msg = cin.readline()
        if msg == "Out!" :
            os.system( "echo 'Worker %d: Exit message!.' >/dev/pts/%d" %\
                    (jnum, pts))
            break
        else :
            index = int( msg)
            os.system( "echo 'Worker %d: Got job at %d.' >/dev/pts/%d" % \
                    (jnum, index , pts))
            status = process( queue[index])
            cout.write( "%d %s %s\n" % (jnum, status, index)) 
    os._exit( 0)
# }}}        
def manager( multi_queue, job_queue, pin, pout) :
# {{{        
    def send_job( worker, next_job) :
# {{{        
        print ( "Sending next job to worker %d, index %d.",\
                worker, next_job)
        pout[worker].write( "%d\n" % next_job) 
        working[work] = True
        next_job += 1
        return
# }}}        
    def wait_worker( pin) :
# {{{        
        print( "Waiting for some worker...")
        msg = pin.readline()
        print( "Message:", msg)
        msg = re.split( r'\ ', msg)
        worker = int(msg[0])
        status = msg[1]
        if status == "DONE" :
            index = int(msg[2])
            target = multi_queue.slots[SLOTS].queue[index].filename
            print( "Worker %d: %s done!" % ( worker, target))
            job_queue[index] = True
            working[worker] = False
        elif status == "ERROR" :
            error = ''.join( msg[2:])
            print( "Worker %d: %s failed!" % ( worker, target))
            print( "He leaved a message: %s" % error)
            working[worker] = False
            while any( working) :
                wait_worker( pin)
            exit( 1)
        else :
            print( "Undefined error!")
            working[worker] = False
            while any( working) :
                wait_worker( pin)
            exit( 255)
        return 0
# }}}        
    next_job = 0
    working = [False] * len( pout)
    while True :
        if all( job_queue) :
            print ( "All done!")
            return 0
        elif all( working) :
            print ( "All workers doing its things!")
            wait_worker( pin)
        elif next_job < len( job_queue) :    
            for i in range( len( working)) :
                if not working[i]: 
                    worker = i
                    break
            send_job( worker, next_job)
# }}}        
def main( job_dict, multi_queue, observate = False) :
# {{{        
    pout = []
    queue = multi_queue.slots[SLOTS]
    job_queue = [False] * queue.get_size()
   #pin, cout = os.pipe()
    pfifo = "/tmp/parent"
    os.mkfifo( pfifo)
   #os.set_inheritable( cout, True)
   #cout = os.fdopen( cout, 'w')
    print( "Prepare to fork!")
    cfifo = "/tmp/child%d"
    for i in range( CPU_COUNT) :
       #cin, pout = os.pipe()
        os.mkfifo( cfifo % i)
        if os.fork() == 0 :
            parent_pid = os.getppid()
            cin = open( cfifo % i , 'r')
            cout = open( pfifo, "w")
            start_job( queue, i, cin, cout, job_dict)
            return 0
        else :
            print ( "HAHA")
            tmp = open( cfifo % i , 'w')
            print ( "HAHA")
            pout.append( tmp)
    pin = open( pfifo, 'r')
    print( "I think it works!")
    manager( queue, job_queue, pin, pout)
    lambda pout, cout : close
    return job_queue
# }}}        
            # job_dict = { 'T1w': job1, 'T2w': job2, 'rest': job3}
            # job_dict["T1w"] = { 'command' :"blablabla in bla out"
            # 'suffix' : "blabla", 'format' : ".nii.gz", }
