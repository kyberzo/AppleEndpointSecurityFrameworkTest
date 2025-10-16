//
//  NSDataSSDEEP.m
//  Extension
//
//  Created by Zimry Ong on 5.12.2020.
//  Based From My LUA Implementation Below
//  NOTE: This accepts a buffer data and hashes it as it is. NO skip characters like 0 or white space.
//  REF:
//     https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
//     http://linux.anu.edu.au/linux.conf.au/2004/papers/junkcode/spamsum/

#import "NSDataSSDEEP.h"

@implementation NSData (NSHash_SSDEEP)

- (nonnull NSString*) SSDEEPHash {
    NSMutableString *retVal = [[NSMutableString alloc] init];
    
    const char *b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    unsigned int block_size = 0;
        
    unsigned int outputLength = SPAMSUM_LENGTH;
    unsigned char left[outputLength + 1];
    unsigned char right[outputLength / 2 + 1];
    
    memset(&left, 0, sizeof(left));
    memset(&right, 0, sizeof(right));
    
    /* compute a reasonable block size */
    if (block_size == 0) {
        block_size = MIN_BLOCKSIZE;
        while (block_size * SPAMSUM_LENGTH < self.length) {
            block_size = block_size * 2;
        }
    }
    // temp
    //const char *fileBytes = (const char*)[self bytes];
    
    while (true) {
        unsigned int k = 0;
        unsigned int j = 0;
        unsigned int h3 = HASH_INIT;
        unsigned int h2 = HASH_INIT;
        
        unsigned int h = [self roll_reset];
        
        for (unsigned int i = 0; i < self.length; i++) {
            unsigned char buffer[1];
            [self getBytes:buffer range:NSMakeRange(i, 1)];
            unsigned int character = (buffer[0] + 256) % 256;
            
            //unsigned int character = (fileBytes[i] + 256) % 256;
            h = [self roll_hash:character];
            h2 = [self sum_hash:character h:h2];
            h3 = [self sum_hash:character h:h3];
            
            if (h % block_size == (block_size - 1)) {
                left[j] = b64[(unsigned int) (h2 % CHAR_IDX_SIZE)];
                if (j < SPAMSUM_LENGTH - 1) {
                    h2 = HASH_INIT;
                    j++;
                }
            }
            if (h % (block_size * 2) == ((block_size * 2) - 1)) {
                right[k] = b64[(unsigned int) (h3 % CHAR_IDX_SIZE)];
                if (k < SPAMSUM_LENGTH / 2 - 1) {
                    h3 = HASH_INIT;
                    k++;
                }
            }
        }
        if (h != 0) {
            left[j] = b64[(unsigned int) (h2 % CHAR_IDX_SIZE)];
            right[k] = b64[(unsigned int) (h3 % CHAR_IDX_SIZE)];
        }
        if (block_size <= MIN_BLOCKSIZE || j >= SPAMSUM_LENGTH / 2) {
            break;
        } else {
            block_size = block_size / 2;
        }

    }
    [retVal appendFormat:@"%d:", block_size];
    [retVal appendFormat:@"%s:", left];
    [retVal appendFormat:@"%s", right];

    return [retVal copy];
}

/*
  a rolling hash, based on the Adler checksum. By using a rolling hash
  we can perform auto resynchronisation after inserts/deletes
  internally, h1 is the sum of the bytes in the window and h2
  is the sum of the bytes times the index
  h3 is a shift/xor based rolling hash, and is mostly needed to ensure that
  we can cope with large blocksize values
*/
- (unsigned int) roll_hash:(unsigned char) c
{
    roll_state.h2 -= roll_state.h1;
    roll_state.h2 += ROLLING_WINDOW * c;

    roll_state.h1 += c;
    roll_state.h1 -= roll_state.window[roll_state.n % ROLLING_WINDOW];

    roll_state.window[roll_state.n % ROLLING_WINDOW] = c;
    roll_state.n++;

    roll_state.h3 = (roll_state.h3 << 5) & 0xFFFFFFFF;
    roll_state.h3 ^= c;

    return roll_state.h1 + roll_state.h2 + roll_state.h3;
}

/*
  reset the state of the rolling hash and return the initial rolling hash value
*/
- (unsigned int) roll_reset
{
    memset(&roll_state, 0, sizeof(roll_state));
    return 0;
}

/* a simple non-rolling hash, based on the FNV hash */
- (unsigned int) sum_hash:(unsigned char) c h:(unsigned int) h
{
    h *= HASH_PRIME;
    h ^= c;
    return h;
}

@end


/*


 function ssdeep_test(input)
     -- [[ SSDEEP]]--
     -- Based on original code (by  Andrew Tridgell) :
     --   o http://linux.anu.edu.au/linux.conf.au/2004/papers/junkcode/spamsum/
     -- A Lua implementation
     -- @zimry ong
     local SsDeep = {}
     do
         -- CONSTANTS
         -- output length of hash
         local SPAMSUM_LENGTH = 64
         local MIN_BLOCKSIZE = 3
         local HASH_PRIME = 0x01000193
         local HASH_INIT = 0x28021967
         local ROLLING_WINDOW = 7
         local roll_state = {}
         roll_state['window'] = {0, 0, 0, 0, 0, 0, 0} -- [ROLLING_WINDOW]
         roll_state['h1'] = 0
         roll_state['h2'] = 0
         roll_state['h3'] = 0
         roll_state['n'] = 0
         -- UTILITY FUNCTIONS
         local function unsign(n)
             if n < 0 then
                 n = 4294967296 + n
             end
             return n
         end
         --[[
             This Function returns only the low 32bit result
         --]]
         local function mul_32(a, b)
             local ah = bit.band(bit.rshift(a, 16), 0xFFFF)
             local al = bit.band(a, 0xFFFF)
             local bh = bit.band(bit.rshift(b, 16), 0xFFFF)
             local bl = bit.band(b, 0xFFFF)
             local high = bit.band(((ah * bl) + (al * bh)), 0xFFFF)
             high = bit.lshift(high, 16)
             return  high + (al * bl)
         end
         --[[
             a rolling hash, based on the Adler checksum. By using a rolling hash
             we can perform auto resynchronisation after inserts/deletes
             internally, h1 is the sum of the bytes in the window and h2
             is the sum of the bytes times the index
             h3 is a shift/xor based rolling hash, and is mostly needed to ensure that
             we can cope with large blocksize values
         --]]
         local function roll_hash(c)
             roll_state.h2 = roll_state.h2 - roll_state.h1
             roll_state.h2 = roll_state.h2 + (ROLLING_WINDOW * c)
             roll_state.h1 = roll_state.h1 + c
             roll_state.h1 = roll_state.h1 - (roll_state.window[(roll_state.n % ROLLING_WINDOW) + 1])
             roll_state.window[(roll_state.n % ROLLING_WINDOW) + 1] = c
             roll_state.n = roll_state.n + 1
             --roll_state.h3 = (roll_state.h3 << 5) & 0xFFFFFFFF;
             roll_state.h3 = bit.lshift(roll_state.h3, 5)
             --roll_state.h3 ^= c;
             roll_state.h3 = bit.bxor(roll_state.h3, c)
             return unsign(roll_state.h1 + roll_state.h2 + roll_state.h3)
         end
         --[[
             reset the state of the rolling hash and return the initial rolling hash value
         --]]
         local function roll_reset()
             roll_state['window'] = {0, 0, 0, 0, 0, 0, 0} -- [ROLLING_WINDOW]
             roll_state['h1'] = 0
             roll_state['h2'] = 0
             roll_state['h3'] = 0
             roll_state['n'] = 0
             return 0
         end
         --[[
             a simple non-rolling hash, based on the FNV hash
         --]]
         local function sum_hash(c, h)
             h = mul_32(h, HASH_PRIME)
             h = bit.bxor(h, c)
             return h
         end
         local function sum_hash1a(c, h)
             h = mul_32(h, HASH_PRIME)
             h = bit.bxor(h, c)
             return unsign(h)
         end
         SsDeep.hash = function(buff)
             -- INIT ()
             local str_b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
             local B64 = {}
             for i = 1, string.len(str_b64) do
                 table.insert(B64, string.byte(str_b64, i))
             end
             --
             local block_size = MIN_BLOCKSIZE
             while (block_size * SPAMSUM_LENGTH < #buff) do
                 block_size = block_size * 2;
             end
             -- SSDEEP 32bit BEGIN
             local left = {}
             local right = {}
             for i = 1, SPAMSUM_LENGTH do
                 table.insert(left, 0)
                 table.insert(right, 0)
             end
             while (true) do
                 local k = 1
                 local j = 1
                 local h3 = HASH_INIT
                 local h2 = HASH_INIT
                 local h = roll_reset() -- 0
                 for i = 1, #buff do
                     --[[
                         at each character we update the rolling hash and
                         the normal hash. When the rolling hash hits the
                         reset value then we emit the normal hash as a
                         element of the signature and reset both hashes
                     --]]
                     local character = (string.byte(buff, i) + 256) % 256
                     h = roll_hash(character)
                     h2 = sum_hash(character, h2)
                     h3 = sum_hash(character, h3)
                     --log:debug('---')
                     --log:debug(string.format('mod: %x', (h % block_size)))
                     --log:debug(string.format('roll:%x', h))
                     --log:debug(string.format('blocksize: %x', block_size - 1))
                     if ((h % block_size) + 1  == block_size ) then
                         --[[we have hit a reset point. We now emit a
                             hash which is based on all chacaters in the
                             piece of the message between the last reset
                             point and this one
                         --]]
                         --log:debug('--reset ----> '.. j )
                         --log:debug(string.format('h2:%x', h2))
                         --log:debug(string.format('h2_mod:%s', (h2 % 64)))
                         left[j] = B64[(h2 % 64) + 1]
                         if (j <= SPAMSUM_LENGTH) then
                             --[[ we can have a problem with the tail
                                 overflowing. The easiest way to
                                 cope with this is to only reset the
                                 second hash if we have room for
                                 more characters in our
                                 signature. This has the effect of
                                 combining the last few pieces of
                                 the message into a single piece
                             --]]
                             h2 = HASH_INIT
                             j= j + 1
                         end
                     end
                     --[[ this produces a second signature with a block size
                         of block_size*2. By producing dual signatures in
                         this way the effect of small changes in the message
                         size near a block size boundary is greatly reduced.
                     --]]
                     --log:debug(string.format('\th: %x', h ))
                     --log:debug(string.format('\th3: %x', h3))
                     if (h % (block_size * 2) + 1 == (block_size * 2)) then
                         right[k] = B64[(h3 % 64) + 1]
                         --log:debug(right[k])
                         --log:debug(string.format('\tidx: %x', (h3 % 64) + 1))
                         if (k <= SPAMSUM_LENGTH / 2 ) then
                             h3 = HASH_INIT
                             k = k + 1
                         end
                     end
                 end -- for
                 --[[
                     If we have anything left then add it to the end. This ensures that the
                     last part of the string is always considered
                 --]]
                 if (h ~= 0) then
                     left[j] = B64[(h2 % 64) + 1]
                     right[k] = B64[(h3 % 64) + 1]
                 end
                 --[[
                     Our blocksize guess may have been way off - repeat if necessary
                 --]]
                 --log:debug('end check : ' .. block_size)
                 if (block_size <= MIN_BLOCKSIZE) or (j>= SPAMSUM_LENGTH / 2) then
                     break
                 else
                     block_size = block_size / 2
                 end
             end -- while
             local str_left = ''
             local str_right = ''
             for i = 1, SPAMSUM_LENGTH do
                 if left[i] > 0 then
                     str_left = str_left .. string.char(left[i])
                 end
                 if right[i] > 0 then
                     str_right = str_right .. string.char(right[i])
                 end
             end
             log:debug(block_size .. ':' .. str_left .. ':' .. str_right)
         end -- SsDeep.hash
         SsDeep.test_roll_hash = function(c)
             return roll_hash(c)
         end
         SsDeep.test_mul_32 = function()
             local l =  mul_32(0xf4679362, 0x01000193)
             log:debug(string.format('%x', l))
         end
     end --do
  
     local blksize, lhash, rhash = SsDeep.hash("helloworld")
     log:debug(blksize .. ':' .. lhash .. ':' .. rhash)
     -- 3:iKJP:b
     blksize, lhash, rhash = SsDeep.hash("hellothere")
     log:debug(blksize .. ':' .. lhash .. ':' .. rhash)
     -- 3:iKUQ:R
     blksize, lhash, rhash = SsDeep.hash("hello, what up?")
     log:debug(blksize .. ':' .. lhash .. ':' .. rhash)
     -- 3:iKJF+tVa:nF+tVa
  
     return
 end
 
 */
