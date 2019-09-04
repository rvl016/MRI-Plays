#include <iostream>
#include <fstream>
#include <string>
//#include <ncurses.h>
//#include <filesystem>
#include <sstream>
#include <string>
#include <limits>

#define SLT_LGT 50
#define WD_LGT 15


using namespace std;
//namespace fs = std::filesystem

bool ReadJson ( int &slc_len, float time_slc[], ifstream &jsonin );


int main (int argc, char **argv)
{
//    cout << argc << endl;
//    cout << argv[1] << endl;    
    if ( argc != 2 ){
        cout << "Exactly one file must be provided!\n";
        exit (1);
    }    
    
    ifstream input;
    ifstream jsonin;
    string addr;  
    float time_slc[SLT_LGT];
    bool flag=0;
    int i, slc_len;
//    input = &argv[0];
    input.open(argv[1]);

   
//  Reading directory
    if ( input.fail() ){
        cerr << "Failed loading input file!\n";
        exit (1);
    }

    while ( 1 ){
        
        input >> addr;
        if ( input.eof() )  break;
//        cout << addr << endl;   
        jsonin.open(addr);
        
        flag = ReadJson ( slc_len,  time_slc, jsonin ); 
        
   
        if ( !flag ) cerr << "No Slice Timing at" << addr << "!\n";
        else {
            for ( i=0; i<slc_len; i++ ){

                cout << time_slc[i] << " ";
            }
            cout << '\n';        
        }
    }
    
    return 0;

}

bool ReadJson ( int &slc_len, float time_slc[] , ifstream &jsonin ){

    string read;
    bool flag=0; 
    slc_len=0;
    
    
    if ( jsonin.fail() ){
        cerr << "Failed loading json file!\n";
    }
    
    while ( !jsonin.eof() ){
        jsonin >> read;
        jsonin.ignore(numeric_limits<streamsize>::max(), '\n');
        if ( read.find("SliceTiming") != -1 ){
            flag=1;
            break;
        }    
    }    

    if ( !flag ){
        jsonin.close();
        return flag;
    }


    while ( 1 ){
        jsonin >> read;
        if ( read[0] == ']' ){
            break;
        }
        
        read = read.substr(0,read.find(","));
        time_slc[slc_len] = stof(read);
        slc_len++;
    }
    
    jsonin.close();
    return flag;  

}    
