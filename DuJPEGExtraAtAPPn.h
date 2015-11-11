//
//  DuJPEGExtraAtAPPn.h
//  mobileguard
//
//  Created by hejunqiu on 15/11/9.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kDuCompressExtraHeadString;
extern const NSUInteger kDuCompressExtraFlag;
extern const int kCompressAPPn;

/* property must be NSString, NSNumber, NSArray, NSDictionary, or NSNull. */
@interface DuJPEGExtraAtAPPn : NSObject
/// Default is kDuCompressExtraHeadString
@property (nonatomic, copy) NSString *headString;
/// 300 present for "3.0.0"
@property (nonatomic, assign) NSUInteger version;
/// Default is current date time.
@property (nonatomic, strong) NSString *compressDateTime;
/// Default is kCompressAPPn.
@property (nonatomic, assign) int APPn;
/// Default is kDuCompressExtraFlag.
@property (nonatomic, assign) NSUInteger flag;

- (instancetype)initWithJSON:(NSDictionary *)JSON;
- (instancetype)initWithJSONString:(NSString *)JSON;

- (NSString *)stringForJSON;
- (void)parse:(NSString *)JSON;
- (BOOL)isValid;
@end
