//
//  NSDataHash.m
//  Extension
//
//  Created by Zimry Ong on 5.12.2020.
// https://github.com/jerolimov/NSHash/tree/master/NSHash

#import "NSDataHash.h"

@implementation NSData (NSHash_AdditionalHashingAlgorithms)

- (nonnull NSString*) SHA1String {
    unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA1(self.bytes, (unsigned int) self.length, output);
    return [self toHexString:output length:outputLength];
}

- (nonnull NSString*) SHA256String {
    unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA256(self.bytes, (unsigned int) self.length, output);
    return [self toHexString:output length:outputLength];
}

- (nonnull NSString*) toHexString:(unsigned char*) data length: (unsigned int) length {
    NSMutableString* hash = [NSMutableString stringWithCapacity:length * 2];
    for (unsigned int i = 0; i < length; i++) {
        [hash appendFormat:@"%02x", data[i]];
        data[i] = 0;
    }
    return [hash copy];
}

@end
