import os
import re

CPU_COUNT = os.cpu_count()
SLOTS = 0

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
                cout.write( jnum, error)
                os._exit( 127)
# }}}        
        def backup() :
# {{{        
            path = targ_ref.get_path()
            os.chdir( path)
            if not os.path.exists( "./tmp") :
                os.mkdir( "tmp")
            os.rename( filename, "./tmp/" + filename)
            metafile = targ_ref.metadata.filename
            tmpMetaName = metafile[0:metafile.find(".")]
            os.rename( metafile, tmpMetaName + \
                    instructs["suffix"] + instructs["format"] + ".meta")
            return
# }}}        
        path = targ_ref.get_path()
        os.chdir( path)
        instructs = job_dict[targ_ref.attribs.sub_type]
        cmd = get_cmd( instructs)
        status = os.system( cmd)
        if status != 0 :
            error = "ERROR Something went wrong with process command!"
            cout.write( jnum, error)
            os._exit( 127)
        else :
            status = "DONE"
        backup()
        return status
# }}}        
    cin = os.fdopen( cin)
    while True :
        msg = cin.read()
        if msg == "Out!" :
            break
        else :
            index = int( msg)
            status = process( queue[index])
            cout.write( jnum, status, index) 
    os._exit( 0)
# }}}        
def manager( multi_queue, job_queue, pin, ppipe) :
# {{{        
    def send_job( worker) :
# {{{        
        ppipe[worker].write( next_job) 
        working[work] = True
        next_job += 1
        return
# }}}        
    def wait_worker( pin) :
# {{{        
        msg = pin.read()
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
    working = [False] * len( ppipe)
    pin = fdopen ( pin, 'r')
    while True :
        if all( job_queue) :
            return 0
        elif all( working) :
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
    ppipe = []
    queue = multi_queue.slots[SLOTS]
    job_queue = [False] * queue.get_size()
    pin, cout = os.pipe()
    os.set_ineritable( cout, True)
    cout = os.fdopen( cout, 'w')
    for i in range( CPU_COUNT) :
        cin, pout = os.pipe()
        os.fork()
        if os.getpid() == 0 :
            parent_pid = os.getppid()
            start_job( queue, i, cin, cout, job_dict)
            return 0
        else :
            pout = os.fdopen( pout, 'w')
            ppipe.append( pout)
    pin = os.fdopen( pin, 'r')
    manager( queue, job_queue, pin, ppipe)
    lambda ppipe, pin, cout : close
    return job_queue
# }}}        
            # job_dict = { 'T1w': job1, 'T2w': job2, 'rest': job3}
            # job_dict["T1w"] = { 'command' :"blablabla in bla out"
            # 'suffix' : "blabla", 'format' : ".nii.gz", }
