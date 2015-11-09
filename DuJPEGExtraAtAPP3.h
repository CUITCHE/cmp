//
//  DuJPEGExtraAtAPP3.h
//  cmp
//
//  Created by hejunqiu on 15/11/9.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kDuCompressExtraHeadString;
extern const NSUInteger kDuCompressExtraFlag;
extern const int kCompressAPPn;
/* property must be NSString, NSNumber, NSArray, NSDictionary, or NSNull. */
@interface DuJPEGExtraAtAPP3 : NSObject
/// Default is ""
@property (nonatomic, copy) NSString *headString;
/// 300 present for "3.0.0"
@property (nonatomic, assign) NSUInteger version;
/// Default is current date time.
@property (nonatomic, strong) NSString *compressDateTime;
/// Default is 3
@property (nonatomic, assign) int APPn;
/// flag
@property (nonatomic, assign) NSUInteger flag;

- (instancetype)initWithJSON:(NSDictionary *)JSON;
- (instancetype)initWithJSONString:(NSString *)JSON;

- (NSString *)stringForJSON;
@end
