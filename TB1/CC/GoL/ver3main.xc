/* Kshitij Upmanyu  | ku17217   | Computer Science
* Bittor Alana     | lo18144   | Maths & Computer Science
* UNIVERSITY OF BRISTOL
* VERSION 3 - CONCBLOCK
*/

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 128                  //image height
#define  IMWD 128                 //image width
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
  char infname[] = "128x128.pgm";     //put your input image path here
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

// Count living neighbours in eight directions
int living(char picture[(IMHT/nblocks)+2][IMWD/8], int x, int y) {
    int directions[8][2] = {{0, 1}, {1, 1}, {1, 0}, {1, (IMHT-1)}, {0, (IMHT-1)}, {(IMWD-1), (IMHT-1)}, {(IMWD-1), 0}, {(IMWD-1), 1}};
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 8; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + directions[i][0]) % IMWD;   // Move in a direction
        mody = (y + directions[i][1]) % IMHT;
        temp = picture[mody][modx/8];       // Retrieve byte where neighbour is
        modx = modx%8;              // Find position of bit in the byte
        picker = picker >> modx;
        temp &= picker;     // Pick the bit
        if (temp != 0) live++;      // Check if alive and add one if so
    }
    return live;
}

// Process that each worker thread runs
int concurrentgol(char picture[(IMHT/nblocks)][IMWD/8], char temppic[(IMHT/nblocks)+2][IMWD/8]) {
    char cbyte, picker, aux, nbyte, live;
    int total = 0;
    for (int y = 0; y < IMHT/nblocks; y++) {    // Go through each line of the block
        for (int x = 0; x < IMWD/8; x++) {      // Go through each byte
            cbyte = picture[y][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {   // Go through each bit of byte
                live = living(temppic, (x*8)+i, y+1);   // Count living neighbours
                aux = picker & cbyte;   // Pick the bit of current pixel
                if(aux != 0 && (live == 2 || live == 3)) {      // Alive and 2-3 live neighbours, stays alive
                    nbyte |= picker;
                    total++;
                }
                else if (aux == 0 && live == 3) {   // Dead and exactly 3 live neighbours, resuscitates
                    nbyte |= picker;
                    total++;
                }
                picker = picker >> 1;
            }
            picture[y][x] = nbyte;  // Write new byte
        }
    }
    return total;
}

////////////////////////////////////////////////////////////////////////////////////
// Overlaps the matrix, each block has two lines more than in the original picture,
// so that blocks won't have to communicate
////////////////////////////////////////////////////////////////////////////////////
void setup(char picture[nblocks][IMHT/nblocks][IMWD/8], char temppic[nblocks][(IMHT/nblocks)+2][IMWD/8]) {
    for (int z = 0; z < nblocks; z++) {
        for (int y = 0; y < IMHT/nblocks; y++) {
            for (int x = 0; x < IMWD/8; x++) {
                if (y == 0) {
                    temppic[z][y][x] = picture[(z + (nblocks - 1)) % nblocks][(IMHT/nblocks) - 1][x];
                }
                else if (y == ((IMHT/nblocks) - 1)) {
                    temppic[z][y+2][x] = picture[(z + 1) % nblocks][0][x];
                }
                temppic[z][y+1][x] = picture[z][y][x];
            }
        }
    }
}

// Count total living cells
int countTotal(int total[nblocks]){
    for(int i = 1; i < nblocks; i++) total[0] += total[i];
    return total[0];
}

/////////////////////////////////////////////////////////////////////////////////////////
//Runs the development of the game
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend pressedbutton, chanend outon, chanend toLED)
{
  int button, rounds, value = 0;
  uchar val;
  uint elapsed = 0;     // In miliseconds
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
  char cpic[nblocks][IMHT/nblocks][IMWD/8]; // Picture divided in blocks
  char temppic[nblocks][(IMHT/nblocks)+2][IMWD/8];  // Picture divided in overlapping blocks
  char temp, magicno;
  int total[nblocks];   // Counters of living cells
  printf("Press SW1 to import image...\n");
  pressedbutton :> button;
  while(button != SW1) {
      pressedbutton :> button;  // Wait until SW1 pressed
  }
  toLED <: 4; // 0100
  for (int z = 0; z < nblocks; z++) {   // Go through each block
    for( int y = 0; y < IMHT/nblocks; y++ ) {   // Go through each line of block
      for( int x = 0; x < IMWD/8; x++ ) { // Go through each byte of line
        temp = 0;
        for (int i = 0; i < 8; i++) {
          c_in :> val;                    // Read the pixel value
          if (val == 255) temp = (temp | 0x01); // Save the value in a byte
          if (i != 7) temp = temp << 1;
        }
        cpic[z][y][x] = temp;   // Add byte with 8 pixels to our matrix
      }
    //printf("\n");
    }
  }
  toLED <: 0; // 0000
  printf( "Processing...\n" );
  rounds = 0;
  t :> time;
  while(1) {
      if(rounds%2) toLED <: 0; // Make LED flicker with parity of rounds
      else toLED <: 1;
      setup(cpic, temppic);     // Copy matrix in overlapping blocks
      par(int i = 0; i < nblocks; i++){
          total[i] = concurrentgol(cpic[i], temppic[i]);   // Run workers
      }
      fromAcc :> value;
      if (value == 1) {
          // Board tilted, show status
          toLED <: 8;
          printf("%d rounds completed\n", rounds);
          printf("%d live cells\n", countTotal(total));
          printf("Time elapsed: %d.%ds\n", elapsed/1000, elapsed%1000);
      }
      while(value == 1) {
          fromAcc :> value;
          if(value == 0) printf("Resuming...\n");
          t :> time;
      }
      pressedbutton :> button;
      if (button == SW2) {  // Output requested
          toLED <: 2;
          outon <: 1;
          for (int z = 0; z < nblocks; z++) {   // Go through each block
              for( int y = 0; y < IMHT/nblocks; y++ ) {   // Go through each line of the block
                  for( int x = 0; x < IMWD/8; x++ ) { // Go through each byte of the line
                      temp = 0;
                      magicno = 0x80;
                      for (int i = 0; i < 8; i++) { // Visit each pixel
                          temp = cpic[z][y][x];
                          if (temp & magicno) val = 255; // If pixel is alive then send 255
                          else val = 0;
                          temp = temp >> 1;
                          magicno = magicno >> 1;
                          c_out <: val;
                      }
                  }
              }
          }
          if(rounds%2) toLED <: 0; // Make LED flicker with round parity
          else toLED <: 1;
          t :> time;
      }
      t :> aux;
      if (aux > time) { // Add time elapsed when counter hasn't overflowed
          elapsed += (aux - time)/100000;
      }
      else {       // Add time elapsed when counter has overflowed
          elapsed += (max - time + aux)/100000;
      }
      // Write time after 100 rounds
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
  char outfname[] = "128x128out2.pgm"; //put your output image path here
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
