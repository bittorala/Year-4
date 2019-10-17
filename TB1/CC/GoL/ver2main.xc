/* Kshitij Upmanyu  | ku17217   | Computer Science
* Bittor Alana     | lo18144   | Maths & Computer Science
* UNIVERSITY OF BRISTOL
* VERSION 2 - CONCOMMALT
*/
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 512                  //image height
#define  IMWD 512                  //image width
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
  char infname[] = "512x512.pgm";     //put your input image path here
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

// Count living neighbours in all directions
int living(char picture[(IMHT/nblocks)][IMWD/8], int x, int y) {
    int directions[8][2] = {{0, 1}, {1, 1}, {1, 0}, {1, (IMHT-1)}, {0, (IMHT-1)}, {(IMWD-1), (IMHT-1)}, {(IMWD-1), 0}, {(IMWD-1), 1}};
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 8; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + directions[i][0]) % IMWD;   // Move in one of the eight directions
        mody = (y + directions[i][1]) % IMHT;
        temp = picture[mody][modx/8]; // Pick the byte where the neighbour belongs
        modx = modx%8;    // Check what bit of the byte it is
        picker = picker >> modx;  // Move picker to select that bit
        temp &= picker;   // Select the bit
        if (temp != 0) live++;  // If bit was one add one to the living neighbours
    }
    return live;
}

// Check if the pixel in the rx position of a row is alive
int islive(char picture[IMWD/8], int rx) {
    char temp;
    int live = 0;
    char picker = 0x80; // 1000 0000
    temp = picture[rx/8]; // Pick the byte that corresponds to the rx'th pixel of the row
    rx = rx%8;    // Find its position inside that byte
    picker = picker >> rx;
    temp &= picker;   // Pick that bit of the byte
    if (temp != 0) live = 1;  // Check if that bit is one or zero
    return live;
}

// Looks for the neighbours who are on the same row or the previous row (up)
int upliving (char picture[(IMHT/nblocks)][IMWD/8], int x, int y) {
    int upd[5][2] = {{0, (IMHT-1)}, {1, (IMHT-1)}, {1, 0}, {(IMWD-1), 0}, {(IMWD-1), (IMHT-1)}}; // all directions (col,row) except the ones of the next row
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 5; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + upd[i][0]) % IMWD;  // Move in a direction
        mody = (y + upd[i][1]) % IMHT;
        temp = picture[mody][modx/8]; // Get the byte where the pixel belongs
        modx = modx%8;            // Check what position the pixel has in the byte
        picker = picker >> modx;
        temp &= picker;   // Pick the pixel
        if (temp != 0) live++;  // Check if pixel is alive and add one if so
    }
    return live;
}

// Looks for the neighbours who are on the same row or the next row (down)
int downliving (char picture[(IMHT/nblocks)][IMWD/8], int x, int y) {
    int downd[5][2] = {{1, 0}, {1, 1}, {0, 1}, {(IMWD-1), 1}, {(IMWD-1), 0}}; // all directions (col,row) except the ones of the prev row
    int live = 0;
    int modx, mody;
    char picker;
    char temp;
    for (int i = 0; i < 5; i++) {
        picker = 0x80; // 1000 0000
        modx = (x + downd[i][0]) % IMWD;  // Move in a direction
        mody = (y + downd[i][1]) % IMHT;
        temp = picture[mody][modx/8];   // Get the byte where the pixel belongs
        modx = modx%8;    // Check what position the pixel has in the byte
        picker = picker >> modx;
        temp &= picker;   // Pick the pixel
        if (temp != 0) live++;    // Check if pixel is alive and add one if so
    }
    return live;
}

// The process that each worker does
int concurrentgol(int parity, char picture[(IMHT/nblocks)][IMWD/8], char modpicture[(IMHT/nblocks)][IMWD/8], chanend prev, chanend next) {
    char cbyte, picker, aux, nbyte, live;
    int livecells = 0;
    for (int y = 1; y < (IMHT/nblocks) - 1; y++) {  // First treat the pixels which are not on the edge lines (all but top and bottom)
        for (int x = 0; x < IMWD/8; x++) {  // Go through each byte
            cbyte = picture[y][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = living(picture, (x*8)+i, y);   // Count living neighbours of the pixel
                aux = picker & cbyte;       // Pick the pixel to see if it is alive
                if(aux != 0 && (live == 2 || live == 3)) {  // Living and two or three living neighbours, stays alive
                    nbyte |= picker;
                    ++livecells;
                }
                else if (aux == 0 && live == 3) {   // Dead and three living neighbours, resuscitates
                    nbyte |= picker;
                    ++livecells;
                }
                picker = picker >> 1;
            }
            modpicture[y][x] = nbyte; // Save modified picture
        }
    }
    if (parity) {   // Blocks with odd parity
        int rx, sx;   // Values to receive and send
        for (int x = 0; x < IMWD/8; x++) {  // Communicate with previous block (send first row, receive last row of the other)
            cbyte = picture[0][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {
                live = 0;
                for (int j = 0; j < 3; j++) { // The even block will want to learn the status of three consecutive pixels
                    prev :> rx;   // Receive a position in which even block is interested
                    sx = islive(picture[0], rx); // Check if this position is alive
                    prev <: sx;       // Tell if it is alive or not
                }
                sx = (((x*8) + i+ IMWD - 1) % IMWD); // Want to learn about the top-left neighbour of bit i in byte x
                prev <: sx;   // Send the position to previous block
                prev :> rx;   // Receive information on top-left neighbour
                live += rx;   // If alive, add one
                sx = (x*8) + i;   // Want to learn about the top neighbour (which is on the same column as our bit)
                prev <: sx;   // Send position to previous block
                prev :> rx;   // Receive information on top neighbour
                live += rx;   // If alive, add one
                sx = (((x*8) + i + 1) % IMWD);  // Want to lelarn about top-right neighbour
                prev <: sx;     // Send pos
                prev :> rx;     // Learn status
                live += rx;     // If alive add one
                live += downliving(picture, (x*8) + i, 0);  // Now check the 5 neighbours of the same row and next row
                aux = picker & cbyte;   // Pick the bit
                if(aux != 0 && (live == 2 || live == 3)) {  // If bit is 1 and 2 or 3 neighbours are alive, it stays alive
                    nbyte |= picker;
                    ++livecells;
                }
                else if (aux == 0 && live == 3) {   // If bit is 0 and exactly 3 neighbours are alive, resuscitate
                    nbyte |= picker;
                    ++livecells;
                }
                picker = picker >> 1;
            }
            modpicture[0][x] = nbyte; // Save modified byte
        }
        for (int x = 0; x < IMWD/8; x++) {  // Communicate with next block (send last row, receive first row of the other)
            cbyte = picture[(IMHT/nblocks) - 1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) { // Visit each bit of a byte
                live = 0;
                sx = (((x*8) + i + IMWD - 1) % IMWD);   // Find column of bottom-left neighbour
                next <: sx;   // Send column
                next :> rx;   // Learn if bottom-left neighbour is alive
                live += rx;   // Add one if so
                sx = (x*8) + i;   // Find column of bottom neighbour
                next <: sx;   // Send column
                next :> rx;   // Learn if bottom neighbour is alive
                live += rx;   // Add one if so
                sx = ((x*8) + i + 1) % IMWD; // Find column of bottom right neighbour
                next <: sx;   // Send column
                next :> rx;   // Learn if bottom right neighbour is alive
                live += rx;   // Add one if so
                for (int j = 0; j < 3; j++) { // We are asked by the next block if three of our bits are alive
                    next :> rx;   // Receive column
                    sx = islive(picture[(IMHT/nblocks)-1], rx);   // Check that column on our last row
                    next <: sx;   // Send value
                }
                live += upliving(picture, (x*8) + i, (IMHT/nblocks) - 1); // Check the other 5 neighbours (same row and previous one)
                aux = picker & cbyte; // Pick our bit
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                    ++livecells;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                    ++livecells;
                }
                picker = picker >> 1;
            }
            modpicture[(IMHT/nblocks)-1][x] = nbyte;
        }
    }
    else {    // Even block, does the same but in reversed order
        int rx, sx;
        for (int x = 0; x < IMWD/8; x++) {    // Send last row to next block and receive first row of next block, three bits at a time
            cbyte = picture[(IMHT/nblocks) - 1][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {   // Find column of the three bottom neighbours and receive data on them
                live = 0;
                sx = (((x*8) + i + IMWD - 1) % IMWD);
                next <: sx;
                next :> rx;
                live += rx;
                sx = (x*8) + i;
                next <: sx;
                next :> rx;
                live += rx;
                sx = ((x*8) + i + 1) % IMWD;
                next <: sx;
                next :> rx;
                live += rx;
                for (int j = 0; j < 3; j++) {   // Send data on positions requested by next block
                    next :> rx;
                    sx = islive(picture[(IMHT/nblocks)-1], rx);
                    next <: sx;
                }
                live += upliving(picture, (x*8) + i, (IMHT/nblocks) - 1);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                    ++livecells;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                    ++livecells;
                }
                picker = picker >> 1;
            }
            modpicture[(IMHT/nblocks)-1][x] = nbyte;
        }
        for (int x = 0; x < IMWD/8; x++) {  // Send first row to the previous block and receive last row of that block
            cbyte = picture[0][x];
            nbyte = 0x00;
            picker = 0x80; // 1000 0000
            for (int i = 0; i < 8; i++) {   // Visit each bit of a byte
                live = 0;
                for (int j = 0; j < 3; j++) {   // Send the status of three requested pixels to previous block
                    prev :> rx;
                    sx = islive(picture[0], rx);
                    prev <: sx;
                }
                sx = (((x*8) + i + IMWD - 1) % IMWD); // Ask information about the three top neighbours
                prev <: sx;
                prev :> rx;
                live += rx;
                sx = (x*8) + i;
                prev <: sx;
                prev :> rx;
                live += rx;
                sx = (((x*8) + i + 1) % IMWD);
                prev <: sx;
                prev :> rx;
                live += rx;
                live += downliving(picture, (x*8) + i, 0);
                aux = picker & cbyte;
                if(aux != 0 && (live == 2 || live == 3)) {
                    nbyte |= picker;
                    ++livecells;
                }
                else if (aux == 0 && live == 3) {
                    nbyte |= picker;
                    ++livecells;
                }
                picker = picker >> 1;
            }
            modpicture[0][x] = nbyte;
        }
    }
    return livecells;
}

// Adds the living cells of each block
int countTotal(int total[nblocks]){
    for(int i = 1; i < nblocks; i++)
        total[0] += total[i];
    return total[0];
}

// Updates the picture after iteration
void update(char picture[nblocks][(IMHT/nblocks)][IMWD/8], char modpicture[nblocks][(IMHT/nblocks)][IMWD/8]) {
    for (int z = 0; z < nblocks; z++) {
        for (int y = 0; y < IMHT/nblocks; y++) {
            for (int x = 0; x < IMWD/8; x++) {
                picture[z][y][x] = modpicture[z][y][x];
            }
        }
    }
}

// Controls the development of the game
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend pressedbutton, chanend outon, chanend toLED)
{
  uchar val;
  int button, rounds, value = 0;
  int total[nblocks]; // Counter of living cells
  uint elapsed = 0; // In miliseconds
  timer t;
  uint time, aux;
  uint max = 0xFFFFFFFF;
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> value;
  while (value == 0) {
      fromAcc :> value;   // Wait for the board to be tilted
  }
  value = 0;
  char cpic[nblocks][IMHT/nblocks][IMWD/8]; // Matrix that depicts the picture
  char mcpic[nblocks][IMHT/nblocks][IMWD/8]; // Updated matrix
  char temp, magicno;
  printf("Press SW1 to import image...\n");
  pressedbutton :> button;
  while(button != SW1) {
      pressedbutton :> button;    // Wait for SW1 to be pressed
  }
  toLED <: 4; // 0100
  for (int z = 0; z < nblocks; z++) { // go through each block
    for( int y = 0; y < IMHT/nblocks; y++ ) {   //  go through all the lines of the block
      for( int x = 0; x < IMWD/8; x++ ) { // go through each byte of the line
        temp = 0;
        for (int i = 0; i < 8; i++) { // visit pixels of the byte
          c_in :> val;                    //read the pixel value
          if (val == 255) temp = (temp | 0x01);
          if (i != 7) temp = temp << 1;
        }
        cpic[z][y][x] = temp;
        mcpic[z][y][x] = 0;
      }
    }
  }
  toLED <: 0; // 0000
  printf( "Processing...\n" );
  rounds = 0;
  chan comm[nblocks];   // Channels for workers' communication
  t :> time;
  while(1) {
      if(rounds%2) toLED <: 0;
      else toLED <: 1;
      par(int i = 0; i < nblocks; i++){
          total[i] = concurrentgol(i%2, cpic[i], mcpic[i], comm[(i+(nblocks-1))%nblocks], comm[i]);  // Set threads to work
      }
      update(cpic, mcpic);  // Copy modified picture into current picture
      fromAcc :> value;
      if (value == 1) {
          toLED <: 8;   // Print status information
          printf("%d rounds completed\n", rounds);
          printf("%d live cells\n", countTotal(total));
          printf("Time elapsed: %d.%ds\n", elapsed/1000, elapsed%1000);
      }
      while(value == 1) {
          fromAcc :> value; // Wait for the board to be untilted, then resume
          if(value == 0) printf("Resuming...\n");
          t :> time;
      }
      pressedbutton :> button;
      if (button == SW2) {    // SW2 pressed, output image
          toLED <: 2;
          outon <: 1;
          for (int z = 0; z < nblocks; z++) {   // go through each block
              for( int y = 0; y < IMHT/nblocks; y++ ) {   //go through each line of block
                  for( int x = 0; x < IMWD/8; x++ ) { //go through each byte
                      temp = 0;
                      magicno = 0x80;
                      for (int i = 0; i < 8; i++) { // visit each pixel
                          temp = mcpic[z][y][x];
                          // Pick the bit, and send the corresponding value to the output manager
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
          t :> time;  // Update the time attribute, so that the time elapsed while exporting is not counted
      }
      t :> aux; // Get current value of timer
      if (aux > time) {   // If time has increased, add difference to elapsed
          elapsed += (aux - time)/100000;
      }
      else {    // There was overflow, add difference to the timer
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
  char outfname[] = "512x512out.pgm"; //put your output image path here
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
