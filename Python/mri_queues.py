#!/usr/bin/python3
from mri_search import MRI_File
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
            if not self.is_empty() :
                self.start += 1 
                return self.queue[self.start - 1]
            else :
                print ( "Queue is empty! I'm out!" )
                return
               #exit( 1)
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
                self.slots.append( self.Queue())
        else :
            self.slots.append( self.Queue())
        return
# }}}        
    def push( self, new, queueNum) :
# {{{        
        self.slots[queueNum].push( new)
        return
# }}}        
    def newQueue( self) :
        self.slots.append( self.Queue())
        return
# }}}        
def mainDFS( head, mode, excludeRules, multi, filterDoneNts) :
# {{{        
    def dfsR( ptr) :
# {{{        
        nonlocal cnt 
        nonlocal lvlCnt
        if isinstance( ptr, MRI_File) :
            if ptr.metadata.status in excludeRules[4] : 
                return
            if filterDoneNts and \
                    set( ptr.flags) == set( ptr.metadata.flags) :
                return
            cnt += 1
            if multi :
                multiQueue.push( ptr, cnt % CPU_COUNT)
            else :
                multiQueue.push( ptr, lvlCnt)
        else :
            if mode == "sub" and ptr.level == "subject" :
                multiQueue.newQueue()
                lvlCnt += 1    
            for child in ptr.child : 
                dfsR( child)
        return
# }}}        
    cnt = 0
    if mode != "file" :
        lvlCnt = -1
    else :
        lvlCnt = 0
    multiQueue = MultiQueue( multi)
    if mode == "file" :
        if multi :
            for i in range( CPU_COUNT) : 
                multiQueue.newQueue()
        else :
            multiQueue.newQueue()
    dfsR( head)
    return multiQueue
# }}}        
def main( head, mode, excludeRules, multi, filterDoneNts = False) :    
    multiQueue = mainDFS( head, mode, excludeRules, \
            multi, filterDoneNts)
    return multiQueue
