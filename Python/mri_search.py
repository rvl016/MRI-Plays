#!/usr/bin/python3
import os
import re
import json
import subprocess
from dialog import Dialog

prepareToCoreg = True
if prepareToCoreg :
    import mri_heuristics 

levels = ( "study", "subject", "session", "type", "sub_type")
yes_dialog = False
mkTreeLog = False

class Tree_node :
# {{{
    ready = 0
    def __init__( self, head, level, attrib = None) :
# {{{        
        if attrib == None :
            self.has_attribs=0
        else :    
            self.has_attribs=1
        self.attrib = attrib
        self.level = level
        self.head = head
        exec( "head.%s.append(self)" % level)
        if self.level != 'sub_type' :
            self.path = None
            self.path_set = False
        self.parent = None
        self.child = []
        self.brother = None
# }}}        
    def __del__( self) :
# {{{        
        exec( "self.head.%s.remove(self)" % self.level)
        if self.parent : self.parent.child.remove( self)
        for i in self.child :
            del i
# }}}        
    def update_attrib( self, attrib) :
# {{{        
        if self.has_attribs == 0 :
            self.attrib( attrib) 
            self.has_attribs = 1
            return 0
        else :
            print ( "Object already has attribute!")
            return 1
# }}}        
    def spawn_child( self, attrib) :
# {{{        
        child = Tree_node( self.head, \
                levels[levels.index( self.level) + 1], attrib) 
        self.child.append( child)
        child.parent = self
        return child
# }}}        
    def spawn_parent( self, attrib) :
# {{{        
        parent = Tree_node( self.head, \
                levels[levels.index( self.level) - 1], attrib)
        self.parent = parent
        parent.child.append( self)
        return parent
# }}}        
    def spawn_brother( self, attrib) :
# {{{        
        brother = Tree_node( self.head, self.level, attrib)
        location = self
        while location.brother :
            location = location.brother
        location.brother = brother
        brother.parent = self.parent
        brother.parent.child.append( brother)
        return brother
# }}}        
    def get_attribs( self) :
# {{{        
        fetching = [self.attrib]
        location = self
        while location.parent :
            location = location.parent
            fetching.append( location.attrib)
        return fetching
# }}}
    def get_path( self, absolute = True) :   
# {{{            
        if self.level == 'sub_type' :
            return None
        if not self.path_set :
            location = self
            path = ""
            while type( location.parent) != Tree_Head :
                location = location.parent
                path = "/" + location.attrib + path
            if absolute :
                location = location.parent
                path = location.root + path
            else : 
                path = "." + path
            self.path = path
            self.path_set = True
        return self.path
# }}}
# }}}
class Tree_Head :
# {{{
    def __init__( self, root_dir) :
# {{{        
        self.root = root_dir
        for i in levels :
            exec("self.%s = []" % i)
        self.attrib = "Tree_header"
        self.level = "head"
        self.child = []
        self.parent = None
# }}}        
    def spawn_child(self, attrib) :
# {{{        
        child = Tree_node( self, levels[0], attrib) 
        child.parent = self
        self.child.append( child)
        return child
# }}}        
# }}}
class MRI_File :
# {{{
    class Attribs :
# {{{
        def __init__( self) :
            self.study = None
            self.subject = None
            self.session = None
            self.type = None
            self.sub_type = None
            self.run = None
            self.echo = None
            self.dxyz = None
            return
# }}}
    def __init__( self, filename, parent) :
# {{{            
        self.parent = parent
        self.filename = filename
        self.fileMtime = None
        self.past = []
        self.aux = {}
        self.ses_aux = {}
        self.matrix_aux = {}
        self.num_past_files = None
        self.num_aux_files = None
        self.num_ses_aux = None
        self.metadata = []
        self.path = ""
        self.path_set = False
        self.aux_set = False
        self.choosen = False
        self.level = "file"
        self.set_attribs()
        self.set_flags()
        return
# }}}        
    def get_path( self, absolute = True) :   
# {{{            
        if not self.path_set :
            location = self
            while location.level != "sub_type" :
                location = location.parent
            path = self.path
            while type( location.parent) != Tree_Head :
                location = location.parent
                path = "/" + location.attrib + path
            if absolute :
                location = location.parent
                path = location.root + path
            else : 
                path = "." + path
            self.path = path
            self.path_set = True
        return self.path
# }}}
    def set_attribs( self) :
# {{{
        if self.filename.find( ".") == -1 :
            print( "Invalid filename!")
            return 1
        else :
            self.attribs = self.Attribs()        
            if self.filename.find( "run-") != -1 :
                self.attribs.run = re.search( 'run-(\d+)',\
                    self.filename).group( 1) 
            if self.filename.find( "echo-") != -1 :
                self.attribs.echo = re.search( 'echo-(\d+)',\
                    self.filename).group( 1) 
            if self.parent.parent.attrib == "anat" :
                self.attribs.sub_type = re.search( 'T(\d)w', \
                    self.filename).group( 0)
            else :
                self.attribs.sub_type = "rest"
            dxyz = str( subprocess.check_output(['3dinfo', \
                    '-d3', self.get_path() + '/' + self.filename]))
            dxyz = dxyz.replace( '\\t', ' ')
            dxyz = dxyz.replace( 'b\'', '').replace( '\\n\'', '')
            self.attribs.dxyz = dxyz
            self.attribs.dx = str( round( float( \
                    dxyz[:dxyz.find( " ")]), 5))
           #if self.attribs.sub_type == "rest" :
           #    print( dxyz)
            self.get_path()
        location = self.parent
        while location.parent :
            exec( "self.attribs.%s = '%s'" % ( location.level,\
                location.attrib))
            location = location.parent
        return
# }}}
    def set_flags( self) :
# {{{
        filename = self.filename
        if filename.find( "+") != -1 :
            flags = filename[filename.index( "+"):len( filename)]
            flags = flags[1:flags.index( ".")]
            flags = re.split( r'\+', flags)
        else :
            flags = []
        self.flags = flags
        return 0
# }}}
    def set_past( self) :
# {{{        
        if not self.path_set : self.get_path()
        dir_ = os.getcwd()
        os.chdir( self.path)
        if os.path.exists( "tmp") :
           #print(os.getcwd())
            os.chdir( "./tmp")
        else :
           #print( self.filename, "hasn't past!")
            return 0
        if self.filename.find( "+") != -1 :
            base_name = self.filename[0:self.filename.index( "+")]
        else :
           #print( "%s is raw!" % self.filename)
            return 0
        for file_ in os.listdir( "./") :
            if os.path.isfile( file_) and file_.startswith( base_name)\
                    and file_.endswith( ".nii.gz") :
                Past_MRI_File( file_, self)
        os.chdir( dir_)
        return len( self.past)
# }}}    
    def set_aux( self) :
# {{{        
        if not self.path_set : self.get_path()
        dir_ = os.getcwd()
        os.chdir( self.path)
        if os.path.exists( "aux") :
            os.chdir( "./aux")
        else :
            return 0
        if self.filename.find( "+") != -1 :
            base_name = self.filename[0:self.filename.index( "+")]
        else :
            base_name = self.filename[0:self.filename.index( ".")]
        for file_ in os.listdir( "./") :
            if os.path.isfile( file_) and file_.startswith( base_name) :
                if file_.endswith( ".nii.gz") :
                    Aux_MRI_File( file_, self)
                elif file_.endswith( ".mat") :
                    Matrix_File( file_, self)
        os.chdir( dir_)
        return
# }}}    
    def set_metadata( self, tslice = False) :
# {{{
        if not self.path_set : self.get_path()
        self.metadata = Meta_data( self.filename + ".meta",\
                self.path)
        if tslice :
            self.set_tslice_data()
        return
# }}}
    def dump_attribs( self) :
# {{{        
        if not self.attribs_set : 
            self.set_attribs()
        return ( [self.run, self.echo, self.flags, self.past])
# }}}
    def set_tslice_data( self, tsliceGen = False) :
# {{{
        if self.attribs.type != "func" :
            return
        if tsliceGen :
            os.chdir( self.get_path())
            tsliceFile = self.metadata.filename + ".tslice"
            if not os.path.isfile( tsliceFile) :
                ptr = open( tsliceFile, 'w') 
                for num in self.metadata.json["SliceTiming"] :
                    ptr.write( str( (1000 * float( num))) + " ")
                ptr.close()
            self.metadata.tsliceFile = tsliceFile
        self.metadata.cutVol = -1
        self.metadata.refVol = -1
        for comment in self.metadata.comment['none'] :
            for token in comment :
                if token.find( 'remove_t=..') != -1 :
                    # De onde vem esse 2? Da puta que pariu.
                    cutVol = int( re.search( 'remove_t=..(\d+)',\
                            token).group( 1)) + 2
                    self.metadata.cutVol = cutVol
                    break
        if self.metadata.cutVol == -1 :
            # De onde vem esse 3? Da puta que pariu.
            cutVol = 3
            self.metadata.cutVol = cutVol
        for comment in self.metadata.comment['none'] :
            for token in comment :
                if token.find( 't=') != -1 and \
                        token.find( 't=..') == -1 :
                    if self.attribs.study == 'COBRE' :
                        self.metadata.refVol = int( re.search( \
                                't=(\d+)', token).group( 1))
                    else :
                        self.metadata.refVol = int( re.search( \
                                't=(\d+)', token).group( 1)) - cutVol
                    break
        if self.metadata.refVol == -1 :
            getTcmd = "3dinfo -nt " + self.filename + " 2>/dev/null"
            tmp = subprocess.check_output( getTcmd, shell = True)
            self.metadata.refVol = int( int( tmp) / 2)
        return
                
# }}}
    def pendingMeta( self) :
# {{{
        matchFlags = set( self.flags) == set( self.metadata.flags['last']) 
        updateMeta = self.metadata.fileMtime > self.fileMtime  
        if matchFlags and updateMeta :
            return False
        return True
# }}}
    def __del__( self) :
# {{{
        self.parent.child.remove( self)
        return
# }}}
# }}}
class Past_MRI_File :
# {{{
    def __init__( self, filename, parent) :
# {{{        
        self.parent = parent
        self.filename = filename
        self.attribs = self.parent.attribs
        self.parent.past.append( self)
        self.path = "/tmp"
        self.path_set = False
        self.level = "pastFile"
        self.set_flags()
        return
# }}}        
    def set_flags( self) :
        MRI_File.set_flags( self)
    def get_path( self) :
        return MRI_File.get_path( self)
# }}}            
class Aux_MRI_File :
# {{{
    def __init__( self, filename, parent) :
# {{{
        self.parent = parent
        self.filename = filename
        self.fileMtime = None
        self.attribs = self.parent.attribs
        self.flags = []
        self.path = "/aux"
        self.path_set = False
        self.level = "auxFile"
        self.metadata = []
        self.set_flags()
        self.get_path()
        self.parent.aux[self.get_type()] = self
        self.fileMtime = os.path.getmtime( self.path + "/" + self.filename)
        self.set_metadata()
        return 
# }}}
    def set_flags( self) :
        MRI_File.set_flags( self)
    def get_path( self) :
        return MRI_File.get_path( self)
    def get_type( self) :
        return self.flags[-1]
    def set_metadata( self) :
        MRI_File.set_metadata( self)
    def pendingMeta( self) :
        return MRI_File.pendingMeta( self)
# }}}
class Matrix_File :
# {{{
    def __init__( self, filename, parent) :
        self.filename = filename
        self.parent = parent
        self.flags = []
        self.path = "/aux"
        self.level = "auxFile"
        self.set_flags()
        self.parent.matrix_aux[self.get_type()] = self
        self.path_set = False
        self.fullPath = self.get_path() + '/' + self.filename
        return
    def get_path( self) :
        return MRI_File.get_path( self) 
    def set_flags( self) :
        MRI_File.set_flags( self)
    def set_flags( self) :
        MRI_File.set_flags( self)
    def get_type( self) :
        return self.flags[-1]
# }}}
class Meta_data :
# {{{
    def __init__( self, filename, path) :
# {{{
        self.path = path
        self.filename = filename
        cut_pos = filename.find( "+") 
        if cut_pos != -1 :
            self.json_file = filename[0:cut_pos] + ".json"
        else :    
            cut_pos = filename.find( ".") 
            self.json_file = filename[0:cut_pos] + ".json"
        if os.path.isfile( self.path + "/" + self.json_file) :
            self.get_json_info( self.json_file)
        if os.path.isfile( self.path + "/" + self.filename) :
            self.fileMtime = os.path.getmtime( path + "/" + filename)
            self.get_instances()
        else :
            self.flags = {'last' : []}
            self.status = {'last' : None}
            self.comment = {'last' : []}
            self.fileMtime = 0
        self.get_logFile()
        return
# }}}
    def get_instances( self) :
# {{{
        metafile = open( self.path + "/" + self.filename, "r")
        data = metafile.readlines()
        metafile.close()
        data = [i.rstrip( "\n") for i in data]
        lenght = len( data)
        data = [re.split( r'\ ', i) for i in data]
        self.flags = {}
        self.status = {}
        self.comment = {}
        if not data :
            print( "Empty metafile!")
            print( "\t=>", metafile)
        else :    
            for i in range( len( data) - 1, -1, -1) :
                flags = list( filter( \
                        None, re.split( r'\+', data[i][0])))
                if flags[-1] in self.flags :
                    continue
                self.flags[flags[-1]] = flags
                self.status[flags[-1]] = int( data[i][1])
                self.comment[flags[-1]] = \
                        re.split( r'_\+_|\+_', data[i][2])
                if i == len( data) - 1 :
                    self.flags['last'] = self.flags[flags[-1]]
                    self.status['last'] = self.status[flags[-1]]
                    self.comment['last'] = self.comment[flags[-1]]
        return
# }}}        
    def get_json_info( self, json_file) :
# {{{        
        os.chdir( self.path)
        #print( json_file)
        info = open( json_file, "r")
        self.json = json.load( info)
        info.close()
        return
# }}}
    def get_logFile( self) :
# {{{
        if self.filename.find( "+") != -1 :
            baseName = self.filename[0:self.filename.index( "+")]
        else :
            baseName = self.filename[0:self.filename.index( ".")]
        self.logFile = baseName + ".nii.gz.log"
        return
# }}}
# }}}
def print_tree( pos, level = 0) :
# {{{
    for a in range( 0, level) : 
        tree.write( "| ")    
    if level < 6 :
        tree.write( "-o-%s\n" % pos.attrib)
        for i in pos.child :
            print_tree( i, level+1)
    else :
        tree.write( "-o-%s\n" % pos.filename)
        for i in pos.past :
            for a in range( 0, level+1) : 
                tree.write( "| ")    
            tree.write( "-o-%s\n" % i.filename)
    return
# }}}
def set_file_stats( pos, includePast = True, includeAux = True) :
# {{{
    if hasattr( pos, 'child') :
        for child in pos.child :
            set_file_stats( child)
    elif type( pos) == MRI_File :
        pos.set_metadata()
        if includePast :
            pos.num_past_files = pos.set_past()
        if includeAux :
            pos.num_aux_files = pos.set_aux()
        pos.fileMtime = os.path.getmtime( pos.path + "/" + pos.filename)
    return
# }}}
def search_MRI( head, excludeRules) :
# {{{
    def pruning( dirs, level, excludeRules) :
# {{{        
        if level == 3 :
            dirs[:] = [d for d in dirs if d in ["anat", "func"]]
# Aqui na verdade é inclusão!! Feio...
        elif level == 1 :
            dirs[:] = [d for d in dirs if d.startswith("sub-")]
            if excludeRules[1] :
                dirs[:] = [d for d in dirs if d in excludeRules[1]]
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!
        elif level == 0 :
            dirs[:] = [d for d in dirs if d not in excludeRules[0]]
        return dirs
# }}}        
    def level_spawn( location, attrib_array, level) :
# {{{        
        def sub_routine( location) :
# {{{
            if location.attrib == "anat" :
                if "T1w" in excludeRules[3] : 
                    location = location.spawn_child( "T2w")
                elif "T2w" in excludeRules[3] :
                    location = location.spawn_child( "T1w")
                else :    
                    location = location.spawn_child( "T1w")
                    location.spawn_brother( "T2w")
                    location = location.parent
            if location.attrib == "func" : location.spawn_child( "rest")
            return
# }}}        
        location = location.spawn_child( attrib_array[0])
        if level == 3 : sub_routine( location)
        for i in dirs[1:len( attrib_array)] :
            location = location.spawn_brother( i)
            if level == 3 : sub_routine( location)
        location = location.parent
        return location
# }}}        
    def getTarg(location, root_dirs ) :
        attrib = os.path.split( root_dirs)[1]
        while location.attrib != attrib :
            location = location.brother
        return location
    os.chdir( head.root)
    if yes_dialog :
        d = Dialog()
        d.infobox( text = "Walking down from " + head.root + "...")
    else :
        print( "Walking down from " + head.root + "...")
    level = 0
    location = head
    for root_dirs, dirs, files in os.walk( ".") :
        new_level = root_dirs.count( os.sep)  
        dirs = pruning( dirs, new_level, excludeRules)
        if dirs and new_level < 4 and new_level > 0 :
# {{{        
            if new_level == 2 :
                if yes_dialog : 
                    d.infobox( text = head.root + root_dirs[1:])
                else :
                    pass
                   #print( head.root + root_dirs[1:])
            if new_level > level :
                level += 1
                location = location.child[0]
                location = getTarg(location, root_dirs )
                location = level_spawn( location, dirs, level)
            elif new_level < level :
                while level != new_level :
                    location = location.parent
                    level -= 1
                location = location.brother 
                location = getTarg(location, root_dirs )
                location = level_spawn( location, dirs, level)
            else :  
                location = location.brother
                location = getTarg(location, root_dirs )
                location = level_spawn( location, dirs, level)
# }}}        
        elif new_level == 4 :
# {{{        
            for i in files :
                if (i.endswith( ".nii.gz") or i.endswith( ".nii")) and \
                        i.startswith( "sub") :
                    if root_dirs.endswith( "anat") :
                        for j in location.child : 
                            if j.attrib == "anat" : 
                                location = j
                                sub_type = re.search( 'T(\d)w', i).\
                                        group( 0)
                                for k in location.child :
                                    if k.attrib == sub_type :
                                        file_node = MRI_File( i, k)
                                        k.child.append( file_node)
                                location = location.parent       
                                break
                    elif root_dirs.endswith( "func") :
                        for j in location.child :
                            if j.attrib == "func" :
                                file_node = MRI_File( i, j.child[0])
                                j.child[0].child.append( file_node)
                                break
# }}}        
        elif new_level == 0 :
            location = level_spawn( location, dirs, level)
# }}}
def main( root_dir, excludeRules) :
    head = Tree_Head( root_dir)
    search_MRI( head, excludeRules)
    set_file_stats( head)
    if mkTreeLog :
        global tree
        os.chdir( head.root)
        tree = open( "treeLog", "w")
        print_tree( head)
        tree.close()
    if prepareToCoreg :
        mri_heuristics.coregister( head)
    return head
