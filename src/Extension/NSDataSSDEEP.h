//
//  NSDataSSDEEP.h
//  MyEndPoint
//
//  Created by Zimry Ong on 5.12.2020.
//
#include <Foundation/Foundation.h>
#include <string.h>

#define SPAMSUM_LENGTH 64
#define MIN_BLOCKSIZE 3
#define HASH_PRIME 0x01000193
#define HASH_INIT 0x28021967
#define ROLLING_WINDOW 7
#define CHAR_IDX_SIZE 64

static struct {
    unsigned char window[ROLLING_WINDOW];
    unsigned int h1, h2, h3;
    unsigned int n;
} roll_state;

@interface NSData (NSHash_Ssdeep)

- (nonnull NSString*) SSDEEPHash;

@end
