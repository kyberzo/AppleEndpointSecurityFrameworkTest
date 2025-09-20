//
//  NSDataHash.h
//  MyEndPoint
//
//  Created by Zimry Ong on 5.12.2020.
//  https://github.com/jerolimov/NSHash/tree/master/NSHash

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

@interface NSData (NSHash_AdditionalHashingAlgorithms)

- (nonnull NSString*) SHA1String;
- (nonnull NSString*) SHA256String;

@end
