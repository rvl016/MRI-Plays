## File and node objects for creating trees of MRI files.
## Author: Ravi do Valle Luz
## Date: 08/09/2019

import os
import re
## ### Header with pointers to all nodes
class Tree_node:
# {{{
    ready = 0
    def __init__(self, head, level, attrib = None):
        
        if attrib == None:
            self.has_attribs=0
        else:    
            self.has_attribs=1

        self.attrib = attrib
       
        self.level = level
        self.head = head
        exec("head.%s.append(self)" % (level))

        self.parent = None
        self.child = []
        self.brother = None

    def __del__(self):
        
        exec("self.head.%s.remove(self)" % (self.level))
        for i in self.child:
            del i

        if self.parent: self.parent.child.remove(self)

    def update_attrib(self, attrib):
        
        if self.has_attribs == 0:
            self.attrib(attrib) 
            self.has_attribs=1
            return 0
        else:
            print ("Object already has attribute!")
            return 1

    def spawn_child(self, attrib):
        
        child = Tree_node(self.head, levels[levels.index(self.level)+1], attrib) 
        self.child.append(child)
        child.parent = self

        return child

    def spawn_parent(self, attrib):

        parent = Tree_node(self.head, levels[levels.index(self.level)-1], attrib)
        self.parent = parent
        parent.child.append(self)
        
        return parent


    def spawn_brother(self, attrib):
        
        brother = Tree_node(self.head, self.level, attrib)
        location = self
        while location.brother:
            location = location.brother
        
        location.brother = brother
        brother.parent = self.parent
        brother.parent.child.append(brother)

        return brother

    def get_attribs(self):

        fetching = [self.attrib]
        location = self
        
        while location.parent:
            location = location.parent
            fetching.append(location.attrib)

        return fetching
# }}}
## ### Nodes of class attributes 
class Tree_Head:
# {{{
    def __init__(self, root_dir):
        self.root = root_dir
        for i in levels:
            exec("self.%s = []" % (i))
    
        self.attrib = "Tree_header"
        self.child = []
        self.parent = None

    def spawn_child(self, attrib):

        child = Tree_node(self, levels[0], attrib) 
        child.parent = self
        self.child.append(child)

        return child

# }}}
## ### File 
class MRI_File:
# {{{
    class Meta_data:
# {{{
        def __init__(self, filename, path):
# {{{
            self.path = path
            self.filename = filename
           #self.instances = [None]
            self.get_instances()
# }}}
        def get_instances(self):
# {{{
            file = open(self.path+self.filename, "r")
            data = file.readlines()
            file.close()

            data = [i.rstrip("\n") for i in data]
            data = [re.split(r' ', i) for i in data]
            if not data:
                self.flags = []
                self.status = None
                self.comment = None
                print("Empty metafile!")

            else:    
                self.flags = list(filter(None,re.split(r'\+',data[-1][0])))
                self.status = int(data[-1][1])
                self.comment = data[-1][2]
# }}}
# }}}
    class Attribs:
# {{{
        def __init__(self):
            self.study = None
            self.subject = None
            self.session = None
            self.type = None
            self.sub_type = None
            self.run = None
            self.echo = None
         
# }}}
    def __init__(self, filename, parent):
# {{{            
        self.parent = parent
        self.filename = filename
        self.path_set = 0
        self.past = []
        self.metadata = []
        
        self.set_attribs()
        self.path_set = False
# }}}        
    def get_path(self, absolute = 1 ):   
# {{{            
        location = self
        path = "/"
        while location.parent:
            location = location.parent
            path = "/" + location.attrib + path

        if absolute:
            location = location.head
            path = head.root + "/" + path
        else: 
            path = "." + path

        self.path = path
        self.path_set = True
        return path
# }}}
    def set_attribs(self):
# {{{
        if self.filename.find(".") == -1:
            print ("Invalid filename!")
            return 1
        else:
            self.attribs = self.Attribs()        
            if self.filename.find("run-") != -1:
                self.attribs.run = re.search('run-(\d+)',\
                    self.filename).group(1) 

            if self.filename.find("echo-") != -1:
                self.attribs.echo = re.search('echo-(\d+)',\
                    self.filename).group(1) 
        
            if self.parent.parent.attrib == "anat":
                self.attribs.sub_type = re.search('T(\d)w', \
                    self.filename).group(0)
            else:
                self.attribs.sub_type = "rest"


        location = self.parent
        while location.parent:
            exec("self.attribs.%s = '%s'" % (location.level,\
                location.attrib))
            location = location.parent
        

# }}}
    def set_flags(self):
# {{{
        filename = self.filename

        if filename.find("+") != -1:
            flags = filename[filename.index("+"):len(filename)]
            flags = re.split(r'\+',flags)
        else:
            flags = None
        
        self.flags = flags
        return 0

# }}}
    def set_past(self):
# {{{        

        if not self.path_set: self.set_path()
        
        os.chdir(self.path)
        if os.path.exists("./tmp"):
            os.chdir("./tmp")
        else:
            print("Object hasn't past!")
            return 1
        
        if self.filename.find("+"):
            base_name = self.filename[0:filename.index("+")]
        else:
            print("Object is raw!")
            return 1

        for file in os.listdir("./"):
            if os.path.isfile(file) and file.startswith(base_name) and file.endswith(".nii.gz"):
                child = Past_MRI_File(file, self)

                self.past.append(child)
        
        return (len(self.past))
# }}}    
    def set_metadata(self):
# {{{
        if not self.path_set: self.set_path()
        
        self.metadata = self.Meta_data(self.filename+".meta", self.path)

# }}}
    def dump_attribs(self):
# {{{        
        if not self.attribs_set:
            self.set_attribs()
        
        return ([self.run, self.echo, self.flags, self.past])
# }}}
    def __del__(self):
# {{{
        for i in self.past:
            del i

# }}}
# }}}
class Past_MRI_File(MRI_File):
# {{{
    def __init__(self, filename, parent):
        
        self.parent = parent
        self.filename = filename
        self.attribs = self.parent.attribs

    def set_flags(self):
        super().set_flags()
  
# }}}            
