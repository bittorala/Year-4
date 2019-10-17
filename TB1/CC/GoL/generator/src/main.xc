#include <stdio.h>
#include "src/pgmIO.h"
#include <stdlib.h>
#include <time.h>

#define IMHT 960
#define IMWD 960

void DataOutStream(unsigned char pic[IMHT][IMWD]){
  int res;
  unsigned char line[ IMWD ];
  char outfname[] = "960x960.pgm"; //put your output image path here
  //int output = 0;
      //outon :> output;
      //Open PGM file
      printf( "DataOutStream: Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
        return;
      }

      //Compile each line of the image and write the image line-by-line
      for( int y = 0; y < IMHT; y++ ) {
        for (int x = 0; x < IMWD; x++) {
          line[x] = pic[y][x];
        }
        _writeoutline( line, IMWD );
        //printf( "DataOutStream: Line written...\n" );
      }

      //Close the PGM image
      _closeoutpgm();
      printf( "DataOutStream: Done...\n" );
}


int main() {
    unsigned char pic[17][17];
    unsigned char picture[IMHT][IMWD];
    /*int temp;
    srand(time(0));
    for (int y = 0; y < IMHT; y++) {
      for (int x = 0; x < IMWD; x++) {
        temp = rand();
        if (temp%2) pic[y][x] = 255;
        else pic[y][x] = 0;
      }
    }*/
    for (int y = 0; y < 17; y++) {
      for (int x = 0; x < 17; x++) {
        pic[y][x] = 0;
      }
    }
    pic[2][4] = 255;
    pic[2][5] = 255;
    pic[2][6] = 255;
    pic[2][10] = 255;
    pic[2][11] = 255;
    pic[2][12] = 255;
    pic[4][2] = 255;
    pic[5][2] = 255;
    pic[6][2] = 255;
    pic[4][7] = 255;
    pic[5][7] = 255;
    pic[6][7] = 255;
    pic[4][9] = 255;
    pic[5][9] = 255;
    pic[6][9] = 255;
    pic[4][14] = 255;
    pic[5][14] = 255;
    pic[6][14] = 255;
    pic[7][4] = 255;
    pic[7][5] = 255;
    pic[7][6] = 255;
    pic[7][10] = 255;
    pic[7][11] = 255;
    pic[7][12] = 255;

    pic[17-2-1][4] = 255;
    pic[17-2-1][5] = 255;
    pic[17-2-1][6] = 255;
    pic[17-2-1][10] = 255;
    pic[17-2-1][11] = 255;
    pic[17-2-1][12] = 255;
    pic[17-4-1][2] = 255;
    pic[17-5-1][2] = 255;
    pic[17-6-1][2] = 255;
    pic[17-4-1][7] = 255;
    pic[17-5-1][7] = 255;
    pic[17-6-1][7] = 255;
    pic[17-4-1][9] = 255;
    pic[17-5-1][9] = 255;
    pic[17-6-1][9] = 255;
    pic[17-4-1][14] = 255;
    pic[17-5-1][14] = 255;
    pic[17-6-1][14] = 255;
    pic[17-7-1][4] = 255;
    pic[17-7-1][5] = 255;
    pic[17-7-1][6] = 255;
    pic[17-7-1][10] = 255;
    pic[17-7-1][11] = 255;
    pic[17-7-1][12] = 255;
    for (int y = 0; y < IMHT; y++) {
      for (int x = 0; x < IMWD; x++) {
        picture[y][x] = pic[y%17][x%17];
      }
    }
    DataOutStream(picture);
    return 0;
}
