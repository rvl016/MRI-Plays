import re
import os
import operator
from shutil import copyfile
#from mri_search import MRI_File
import mri_search

# -f <f> fractional intensity threshold (0->1); default=0.5; smaller values give larger brain outline estimates
# -g <g> vertical gradient in fractional intensity threshold (-1->1); default=0; positive values give larger brain outline at bottom, smaller at top
def SkullStrip( mriObj) :
# {{{
    f = .5
    g = .0
    par = (f, g)
    for token in mriObj.metadata.comment[-1] :
        delta = deltaPar[token]
        par = tuple( map( operator.add, par, delta))
    f, g = par
    return "-f %.3f -g %.3f" % par
# }}}
def mcflirt( mriObj, stage) :
# {{{
    # Make this crap better!
    comment = mriObj.metadata.comment[0]
    ext = '-refvol %s' % mriObj.metadata.refVol
    if stage == 0 and 'steep_motion' in comment :
        ext += ' -stages 1 -smooth 7.0 -dof 6 -sinc_final'
        return ext
    if 'motion' in comment :
        if stage == 1 :
            ext = ext + ' -stages 2 -dof 6 -sinc_final -smooth 3.0'
            return ext
        elif stage == 2 :
            if mriObj.attribs.study == 'NMorphCH' :
                ext = ext + ' -stages 4 -dof 12 -sinc_final'
            else :
                ext = ext + ' -stages 4 -dof 6 -sinc_final'
            return ext
        elif stage == 3 :
            return None
    elif '+motion' in comment :
        if stage == 1 :
            ext = ext + ' -stages 1 -dof 6 -sinc_final -smooth 5.0'
            return ext
        elif stage == 2 :
            ext = ext + ' -stages 2 -dof 6 -sinc_final -smooth 3.0'
            return ext
        elif stage == 3 :
            if mriObj.attribs.study == 'NMorphCH' :
                ext = ext + ' -stages 4 -dof 12 -sinc_final'
            else :
                ext = ext + ' -stages 4 -dof 6 -sinc_final'
            return ext
    else : 
        if stage == 1 :
            if mriObj.attribs.study == 'NMorphCH' :
                ext = ext + ' -stages 4 -dof 12 -sinc_final'
            else :
                ext = ext + ' -stages 4 -dof 6 -sinc_final'
            return ext
    return None
# }}}
def coregister( head) :
# {{{
    def dfsT1w( ptr, T1w, restFiles) :
        # {{{
        if ptr.level == 'type' and ptr.attrib == 'func' :
            funcPtr = ptr
            funcPtr = funcPtr.child[0]
            for restFile in funcPtr.child :
                restFiles.append( restFile)
            return
        if ptr.level == 'sub_type' and ptr.attrib != 'T1w' :
            return
        if isinstance( ptr, mri_search.MRI_File) :
            # SO FUCKING UGLY!
            if not set( ['strip', 'automask']).issubset( set( ptr.flags)) :
               #print( "\t", ptr.filename, "where are flags? Out!")
                return False
            if not 'strip' in ptr.metadata.status :  
                print( "What?! %s" % ptr.filename)
            if not 'automask' in ptr.metadata.status :  
                print( "What?! %s" % ptr.filename)
            ptrStatus = max( ptr.metadata.status['strip'], \
                    ptr.metadata.status['automask'])
           #print( ptr.filename, "status %d!" % ptrStatus)
            if ptrStatus > 2 :
                return False
            if len( T1w) == 0 :
                T1w.append( ptr)
                return False
            T1wStatus = max( T1w[0].metadata.status['strip'], \
                    T1w[0].metadata.status['automask'])
            if ptrStatus > T1wStatus :
                return False
            if ptrStatus == T1wStatus :
                T1w.append( ptr)
                return False
           #print( "Ow, better file here!")
            T1w.clear()
            T1w.append( ptr)
            return False
        else :
            for child in ptr.child :
                if dfsT1w( child, T1w, restFiles) == True :
                    return True
# }}} 
    sessions = head.session
    for ses in sessions :
        T1w = []
        restFiles = []
        dfsT1w( ses, T1w, restFiles)
        if len( restFiles) == 0 :
            continue
        if len( T1w) == 0 :
# {{{
           #print( "No T1w found for %s/%s!" % \
                   #(ses.parent.attrib, ses.attrib))
            dummy = []
            T1w = [[]]
            date = []
            for child in ses.parent.child :
                date.append( int( child.attrib[4:]))
                dfsT1w( child, T1w[-1], dummy)
                T1w.append( [])
            best = None
            bestTimeDiff = None
            for i in range( len( ses.parent.child)) :
                if len( T1w[i]) > 0 :
                    timeDiff = abs( int( ses.attrib[4:]) - date[i])
                    if bestTimeDiff == None or bestTimeDiff > timeDiff :
                        best = i
                        bestTimeDiff = timeDiff
           #if best != None :
               #print( "\tBut found in %s!" % \
                       #ses.parent.child[best].attrib)
           #else :
               #print( "Opss, no T1w reference for %s!" % ses.attrib)
           #    continue
            if best == None :
                print( "Opss, no T1w reference for %s!" % ses.attrib)
                os.exit( 255)
            T1w = T1w[best]
# }}}
       #print( "T1w found for %s/%s!" % \
               #(ses.parent.attrib, ses.attrib))
        if len( T1w) > 1 :
            print( "WARNING: %s" % T1w[0].filename)
        for mriObj in restFiles :
            mriObj.ses_aux["T1wRef"] = T1w[0]
        T1w[0].choosen = True
    return
# }}}

# SkullStrip heuristic
deltaPar = {}
deltaPar["small_cut_above"] = ( -.075, -.1) 
deltaPar["some_cut_above"] = ( -.125, -.2)
deltaPar["big_cut_above"] = ( -.225, -.275)
deltaPar["small_cut_under"] = ( -.05, .75)
deltaPar["some_cut_under"] = ( -.125, .125)
deltaPar["little_extrapolation_above"] = ( .05, .05)
deltaPar["some_extrapolation_above"] = ( .1, .05)
deltaPar["little_extrapolation_under"] = ( .025, -.05)
deltaPar["some_extrapolation_under"] = ( .075, -.1)
deltaPar["big_extrapolation_under"] = ( .175, -.175)
deltaPar["neck_extrapolation"] = ( .1, -.1)
deltaPar["eyes_extrapolation"] = ( 0, 0)
