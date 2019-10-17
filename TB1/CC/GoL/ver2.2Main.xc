// VERSION 2.2
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 1024                  //image height
#define  IMWD 1024                  //image width
#define     SW1 14
#define     SW2 13
#define nblocks 8

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0]: port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0]: port p_sda = XS1_PORT_1F;
on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs


#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

int showLEDs(out port p, chanend fromVisualiser) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromVisualiser :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}


void buttonListener(in port b, chanend pressedbutton) {
  int r,aux;
  while (1) {
    b :> r;
    b when pinseq(15) :> aux;
    if ((r==SW1) || (r==SW2)) {     // if either button is pressed
        pressedbutton <: r;
    }
    else pressedbutton <: 0;
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  char infname[] = "1024x1024.pgm";     //put your input image path here
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
      //printf( "-%4.1d ", line[ x ] ); //show image values
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

int living(char picture[(IMHT/nblocks)][IMWD/8], int x, int y) {
    int directions[8][2] = {{0, 1}, {1, 1}, {1, 0}, {1, (IMHT-1)}, {0, (IMHT-1)}, {(IMWD-1), (IMHT-1)}, {(IMWD-1), 0}, {(IMWD-1), 1}};
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 8; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + directions[i][0]) % IMWD;
        mody = (y + directions[i][1]) % IMHT;
        if(mody >= IMHT/nblocks || modx >= IMWD)  printf("(%d, %d) -> (%d, %d)\n", x, y, modx, mody);
        temp = picture[mody][modx/8];
        modx = modx%8;
        picker = picker >> modx;
        temp &= picker;
        if (temp != 0) live++;
    }
    return live;
}

int livingedge(char picture[3][IMWD/8], int x) {
    int directions[8][2] = {{0, 1}, {1, 1}, {1, 0}, {1, (IMHT-1)}, {0, (IMHT-1)}, {(IMWD-1), (IMHT-1)}, {(IMWD-1), 0}, {(IMWD-1), 1}};
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 8; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + directions[i][0]) % IMWD;
        mody = (1 + directions[i][1]) % IMHT;
        //printf("(%d, %d) -> (%d, %d)\n", x, 1, modx, mody);
        temp = picture[mody][modx/8];
        modx = modx%8;
        picker = picker >> modx;
        temp &= picker;
        if (temp != 0) live++;
    }
    return live;
}

void concurrentgol(int parity, char picture[(IMHT/nblocks)][IMWD/8], char modpicture[(IMHT/nblocks)][IMWD/8], chanend prev, chanend next) {
    char cbyte, picker, aux, nbyte, live;
    char edgepic[3][IMWD/8];
    for (int y = 1; y < (IMHT/nblocks) - 1; y++) {
        for (int x = 0; x < IMWD/8; x++) {
            cbyte = picture[y][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = living(picture, (x*8)+i, y);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                }
                picker = picker >> 1;
            }
            modpicture[y][x] = nbyte;
        }
    }
    if(parity) {
        for (int x = 0; x < IMWD/8; x++) {
            prev <: picture[0][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            prev :> edgepic[0][x];
            edgepic[1][x] = picture[0][x];
            edgepic[2][x] = picture[1][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            cbyte = edgepic[1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = livingedge(edgepic, (x*8)+i);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                }
                picker = picker >> 1;
            }
            modpicture[0][x] = nbyte;
        }
        for (int x = 0; x < IMWD/8; x++) {
            next :> edgepic[2][x];
            edgepic[0][x] = picture[(IMHT/nblocks)-2][x];
            edgepic[1][x] = picture[(IMHT/nblocks)-1][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            cbyte = edgepic[1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = livingedge(edgepic, (x*8)+i);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                }
                picker = picker >> 1;
            }
            modpicture[(IMHT/nblocks)-1][x] = nbyte;
            next <: picture[(IMHT/nblocks)-1][x];
        }
    }
    else {
        for (int x = 0; x < IMWD/8; x++) {
            next :> edgepic[2][x];
            edgepic[0][x] = picture[(IMHT/nblocks)-2][x];
            edgepic[1][x] = picture[(IMHT/nblocks)-1][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            cbyte = edgepic[1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = livingedge(edgepic, (x*8)+i);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                }
                picker = picker >> 1;
            }
            modpicture[(IMHT/nblocks)-1][x] = nbyte;
            next <: picture[(IMHT/nblocks)-1][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            prev <: picture[0][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            prev :> edgepic[0][x];
            edgepic[1][x] = picture[0][x];
            edgepic[2][x] = picture[1][x];
        }
        for (int x = 0; x < IMWD/8; x++) {
            cbyte = edgepic[1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = livingedge(edgepic, (x*8)+i);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                }
                picker = picker >> 1;
            }
            modpicture[0][x] = nbyte;
        }
    }
}

void update(char picture[nblocks][(IMHT/nblocks)][IMWD/8], char modpicture[nblocks][(IMHT/nblocks)][IMWD/8]) {
    for (int z = 0; z < nblocks; z++) {
        for (int y = 0; y < IMHT/nblocks; y++) {
            for (int x = 0; x < IMWD/8; x++) {
                picture[z][y][x] = modpicture[z][y][x];
            }
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend pressedbutton, chanend outon, chanend toLED)
{
  uchar val;
  int button, rounds, value = 0;
  uint elapsed = 0;
  timer t;
  uint time, aux;
  uint max = 0xFFFFFFFF;
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> value;
  while (value == 0) {
      fromAcc :> value;
  }
  value = 0;
  char cpic[nblocks][IMHT/nblocks][IMWD/8];
  char mcpic[nblocks][IMHT/nblocks][IMWD/8];
  char temp, magicno;
  printf("Press SW1 to import image...\n");
  pressedbutton :> button;
  while(button != SW1) {
      pressedbutton :> button;
  }
  toLED <: 4; // 0100
  for (int z = 0; z < nblocks; z++) {
    for( int y = 0; y < IMHT/nblocks; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD/8; x++ ) { //go through each pixel per line
        temp = 0;
        for (int i = 0; i < 8; i++) {
          c_in :> val;                    //read the pixel value
          if (val == 255) temp = (temp | 0x01);
          if (i != 7) temp = temp << 1;
        }
        cpic[z][y][x] = temp;
        mcpic[z][y][x] = 0;
      }
    printf("\n");
    }
  }
  toLED <: 0; // 0000
  printf( "Processing...\n" );
  rounds = 0;
  chan comm[nblocks];
  t :> time;
  while(1) {
      if(rounds%2) toLED <: 0;
      else toLED <: 1;
      par(int i = 0; i < nblocks; i++){
          concurrentgol(i%2, cpic[i], mcpic[i], comm[(i+(nblocks-1))%nblocks], comm[i]);
      }
      update(cpic, mcpic);
      fromAcc :> value;
      if (value == 1) {
          toLED <: 8;
          printf("%d rounds completed\n", rounds);
          printf("%d live cells\n", val);
          printf("Time elapsed: %d.%ds\n", elapsed/1000, elapsed%1000);
      }
      while(value == 1) {
          fromAcc :> value;
          if(value == 0) printf("Resuming...\n");
          t :> time;
      }
      pressedbutton :> button;
      //if (rounds == 0) button = SW2;
      if (button == SW2) {
          toLED <: 2;
          outon <: 1;
          for (int z = 0; z < nblocks; z++) {
              for( int y = 0; y < IMHT/nblocks; y++ ) {   //go through all lines
                  for( int x = 0; x < IMWD/8; x++ ) { //go through each pixel per line
                      temp = 0;
                      magicno = 0x80;
                      for (int i = 0; i < 8; i++) {
                          temp = mcpic[z][y][x];
                          if (temp & magicno) val = 255;
                          else val = 0;
                          temp = temp >> 1;
                          magicno = magicno >> 1;
                          //printf(" %d ", temp);
                          c_out <: val;
                      }
                  }
                  //printf("\n");
              }
          }
          if(rounds%2) toLED <: 0;
          else toLED <: 1;
          t :> time;
      }
      t :> aux;
      if (aux > time) {
          elapsed += (aux - time)/100000;
      }
      else {
          elapsed += (max - time + aux)/100000;
      }
      if(rounds == 99) printf("Time elapsed after 100 rounds: %d.%ds\n", elapsed/1000, elapsed);
      time = aux;
      rounds++;
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in, chanend outon)
{
  int res;
  uchar line[ IMWD ];
  char outfname[] = "1024x1024out.pgm"; //put your output image path here
  int output = 0;
  while(1) {
      outon :> output;
      //Open PGM file
      printf( "DataOutStream: Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
        return;
      }

      //Compile each line of the image and write the image line-by-line
      for( int y = 0; y < IMHT; y++ ) {
        for( int x = 0; x < IMWD; x++ ) {
          c_in :> line[ x ];
        }
        _writeoutline( line, IMWD );
       // printf( "DataOutStream: Line written...\n" );
      }

      //Close the PGM image
      _closeoutpgm();
      printf( "DataOutStream: Done...\n" );
  }
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x > 30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
      else toDist <: 0;
    }
    else if (tilted) {
      if (x < 30) {
          tilted = 1 - tilted;
          toDist <: 0;
      }
      else toDist <: 1;
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

i2c_master_if i2c[1];               //interface to orientation
chan c_inIO, c_outIO, c_control, pressedbutton, outon, pattern;    //extend your channel definitions here

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    on tile[0]: orientation(i2c[0],c_control);        //client thread reading orientation data
    on tile[0]: DataInStream(c_inIO);          //thread to read in a PGM image
    on tile[0]: DataOutStream(c_outIO, outon);       //thread to write out a PGM image
    on tile[1]: distributor(c_inIO, c_outIO, c_control, pressedbutton, outon, pattern);//thread to coordinate work on image
    on tile[0]: buttonListener(buttons, pressedbutton);
    on tile[0]: showLEDs(leds, pattern);
  }

  return 0;
}
