/* Kshitij Upmanyu  | ku17217   | Computer Science
* Bittor Alana     | lo18144   | Maths & Computer Science
* UNIVERSITY OF BRISTOL
* VERSION 1
*/
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 128            //image height
#define  IMWD 128            //image width
#define  SW1 14
#define  SW2 13
#define  nblocks 8          //number of blocks (and therefore of workers)
#define  bits 8
#define  blocksize IMHT/nblocks

typedef unsigned char uchar;      //using uchar as shorthand
typedef char stype;

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

//Finds the live pixels of the picture, and sends their positions to the buffers
void findlive(stype pic[nblocks][blocksize][IMWD/bits], chanend toBuffer, chanend shutdown) {
    stype temp, aux, picker;
    for (int z = 0; z < nblocks; z++) {         // Visit each block
        for (int y = 0; y < blocksize; y++) { // Visit each row of the block
            for (int x = 0; x < IMWD/bits; x++) { // Each item of the matrix encodes 'bits' many bits
                picker = 0x01;
                picker = picker << (bits - 1);
                temp = pic[z][y][x];
                for (int i = 0; i < bits; i++) {
                    aux = temp & picker;    // Pick the i'th bit (starting from msb)
                    if (aux) {
                        // Pixel was alive
                        shutdown <: 2;
                        toBuffer <: ((blocksize)*z) + y; // Send row of the pixel
                        toBuffer <: x*bits + i;             // Send column of the pixel
                    }
                    else shutdown <: 0; // Tell the buffer it was a dead pixel
                    picker = picker >> 1;
                }
            }
        }
    }
    shutdown <: 1;
}

// Sends the position of the living cells to the add process
void buffer(chanend receive, chanend send, chanend shutdown, chanend shutadd) {
    int x, y;
    int end = 0;
    while(end != 1) {
        shutdown :> end;
        if (end == 2) {     // There is a living pixel coming in
            receive :> y;   // Receive row
            //printf("%d\n", y);
            receive :> x;   // Receive column
            //printf("%d\n", x);
            shutadd <: 0;
            send <: y;      // Send row
            send <: x;      // Send column
        }
        else if (end == 1){
            shutadd <: 1;   // The whole picture was processed
        }
    }
}

// We set position[i] to be 0xF0^i, that is, an F followed by i zeros, in hex
void create(stype position[bits/4]) {
    stype temp = 0xF;
    for (int i = 0; i < (bits/4); i++) {
        position[i] = temp;
        temp = temp << 4;
    }
}

// Receive the position of living cells and add one to the counter of all their neighbours
void add(stype live[nblocks][blocksize][4*IMWD/bits], chanend fromBuffer, chanend shutdown) {
    int directions[8][2] = {{0, 1}, {1, 1}, {1, 0}, {1, (IMHT-1)}, {0, (IMHT-1)}, {(IMWD-1), (IMHT-1)}, {(IMWD-1), 0}, {(IMWD-1), 1}};
    int x, y, z, modx, mody, pos;
    int end = 0;
    stype position[bits/4];
    create(position);
    while(end != 1) {
        shutdown :> end;    // First the buffer tells if a position is expected
        if(!end) {
            fromBuffer :> y;    // Receive row
            fromBuffer :> x;    // Receive column
            for(int i = 0; i < 8; i++) {
                // Move in the direction given by directions
                modx = (x + directions[i][0]) % IMWD;
                mody = (y + directions[i][1]) % IMHT;
                z = (mody/(blocksize));  // Find in which block this position is
                pos = (bits/4) - (modx%(bits/4)) - 1; // Find the position of our 4-bit set
                live[z][mody%(blocksize)][modx/(bits/4)] += 0x01 << 4*pos;  // Add one to the 4-bit set
            }
        }
    }
}

// The process that each worker will do concurrently
int concurrentgol(stype picture[blocksize][IMWD/bits], stype living[blocksize][IMWD/(bits/4)]) {
    stype cbyte, picker, aux, nbyte, live;
    int total = 0;  // living pixels in the block
    int pos;
    stype position[bits/4];
    create(position);   // We create pickers of 4-bit sets
    for (int y = 0; y < blocksize; y++) {   // Go through the lines of the block
        for (int x = 0; x < IMWD/bits; x++) {   // Go through the columns of the block
            cbyte = picture[y][x];      // Retrieve set of pixels (bits)
            nbyte = 0x00;
            picker = 0x01 << (bits - 1);  // Pick bits starting from the msb
            for (int i = 0; i < bits; i++) {
                pos = bits/4 - i%(bits/4) - 1; // Find the position of the 4-bit set
                live = living[y][(x*bits + i)/(bits/4)];
                live &= position[pos];  // Erase everything that is not in the 4-bit set
                live = live >> 4*pos;   // Move the 4-bit set to lsb positions
                aux = picker & cbyte;   // Pick the pixel we are processing
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                    total++;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                    total++;
                }
                picker = picker >> 1;
            }
            picture[y][x] = nbyte;  // Update set of pixels
        }
    }
    return total;
}

// Set living neighbours to zero
void update(stype live[nblocks][blocksize][IMWD/(bits/4)]) {
    for (int z = 0; z < nblocks; z++) {
        for (int y = 0; y < blocksize; y++) {
            for (int x = 0; x < IMWD/(bits/4); x++) {
                live[z][y][x] = 0;
            }
        }
    }
}

// Add up the living cells of each block
int totaladd(int total[nblocks]) {
   int live = 0;
   for (int i = 0; i < nblocks; i++) {
       live += total[i];
   }
   return live;
}

// Set living cells of each block to zero
void totalreset(int total[nblocks]) {
    for (int i = 0; i < nblocks; i++) {
        total[i] = 0;
    }
}

// Controls the development of the game
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend pressedbutton, chanend outon, chanend toLED)
{
  uchar val;
  int button, rounds, value = 0;
  uint elapsed = 0;     // In miliseconds
  timer t;
  uint time, aux;
  uint max = 0xFFFFFFFF;
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> value;
  while (value == 0) {
      fromAcc :> value;     // Wait for the board to be tilted
  }
  value = 0;
  stype live[nblocks][blocksize][IMWD/(bits/4)];    // Matrix to count living neighbours (divided in blocks)
  stype cpic[nblocks][blocksize][IMWD/bits];        // Matrix which depicts the picture (divided in blocks)
  stype temp, picker;
  printf("Press SW1 to import image...\n");
  pressedbutton :> button;
  while(button != SW1) {
      pressedbutton :> button;  // Wait for SW1 to be pressed
  }
  toLED <: 4; // 0100
  for (int z = 0; z < nblocks; z++) {
    for( int y = 0; y < blocksize; y++ ) {      // go through all lines
      for( int x = 0; x < IMWD/bits; x++ ) {    // go through each set of pixels
        temp = 0;
        for (int i = 0; i < bits; i++) {
          c_in :> val;                    //read the pixel value
          if (val == 255) temp |=  0x01;    // if pixel is alive then add a one
          if (i != (bits-1)) temp = temp << 1;  // move towards its position in the bit set
        }
        cpic[z][y][x] = temp;
      }
    }
  }
  toLED <: 0; // 0000
  printf( "Processing...\n" );
  rounds = 0;
  int total[nblocks];   // counters of living cells of each block
  chan toBuffer, fromBuffer, shutBuffer, shutAdd;
  t :> time;

  while(1) {
      update(live);     // Set living neighbours to 0
      if(rounds%2) toLED <: 0;  // Make LED switch depending on round parity
      else toLED <: 1;
      // First, find living cells and add one to their neighbours' counters
      par{
          findlive(cpic, toBuffer, shutBuffer);
          buffer(toBuffer, fromBuffer, shutBuffer, shutAdd);
          add(live, fromBuffer, shutAdd);
      }
      // Then, set workers to run
      par(int i = 0; i < nblocks; i++) {
          total[i] = concurrentgol(cpic[i], live[i]);
      }

      // Check if the board is tilted
      fromAcc :> value;
      if (value == 1) {
          toLED <: 8;
          // Print status information
          printf("%d rounds completed\n", rounds);
          printf("%d live cells\n", totaladd(total));
          printf("Time elapsed: %d.%ds\n", elapsed/1000, elapsed%1000);
      }
      while(value == 1) {
          // Wait for the board to be untilted, then resume
          fromAcc :> value;
          if(value == 0) printf("Resuming...\n");
          t :> time;    // Update the time attribute, so that the time elapsed while paused is not counted
      }
      pressedbutton :> button;
      if (button == SW2) {  // SW2 pressed, output image
          toLED <: 2;
          outon <: 1;
          for (int z = 0; z < nblocks; z++) {   // go through each block
              for( int y = 0; y < blocksize; y++ ) {   //go through each line of the block
                  for( int x = 0; x < IMWD/bits; x++ ) { //go through each set of bits
                      picker = 0x01 << (bits-1);
                      temp = cpic[z][y][x];
                      for (int i = 0; i < bits; i++) {  // go through each pixel
                          // Pick the bit, and send the corresponding value to the output manager
                          if (temp & picker) val = 255;
                          else val = 0;
                          picker = picker >> 1;
                          c_out <: val;
                      }
                  }
              }
          }
          if(rounds%2) toLED <: 0;
          else toLED <: 1;
          t :> time; // Update the time attribute, so that the time elapsed while exporting is not counted
      }
      totalreset(total); // Reset counters for the next round
      t :> aux;
      if (aux > time) {     // If the timer has increased, there was no overflow
          elapsed += (aux - time)/100000;   // Add the amount of miliseconds elapsed since last iteration
      }
      else {        // If the timer seems to have decreased, there was an overflow
          elapsed += (max - time + aux)/100000; // Add the amount of miliseconds elapsed since last iteration
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
  char outfname[] = "128x128out.pgm"; //put your output image path here
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
