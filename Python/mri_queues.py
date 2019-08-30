#!/usr/bin/python3
import os
CPU_COUNT = os.cpu_count()

class MultiQueue :
# {{{        
    class Queue:
# {{{        
        def __init__( self) :
            self.queue = []
            self.start = self.end = 0
            return
        def is_empty( self) :
            return self.start == self.end
        def get_size( self) :
            return self.end - self.start 
        def get_end( self) :
            return self.end
        def pop( self) :
            if not self.is_empty :
                self.start += 1 
                return self.queue[self.start - 1]
            else :
                print ( "Queue is empty! I'm out!" )
                exit( 1)
            return
        def push( self, new) :
            self.end += 1
            self.queue.append( new)
            return
# }}}        
    def __init__( self, multi) :
# {{{        
        self.slots = []
        if multi :
            for i in range( CPU_COUNT) : 
                self.slots.append( Queue())
        else :
            self.slots.append ( Queue())
        return
# }}}        
    def push( self, new, i) :
# {{{        
        self.slots[i].push( new)
        return
# }}}        
# }}}        
def mainDFS( head, multi) :
# {{{        
    def dfsR( ptr, multi) :
        if type( ptr) is MRI_File :
            cnt += 1
            if multi :
                multiQueue.push( ptr, count % CPU_COUNT)
            else :
                multiQueue.push( ptr, count)
        else :
            for child in ptr.child: 
                dfsR( child, multiQueue)
    cnt = 0
    multiQueue = MultiQueue( multi)
    dfsR( head, multiQueue)
    return multiQueue
# }}}        
def main( head, multi = False) :    
    multiQueue = mainDFS( head, multi)
    return multiQueue
