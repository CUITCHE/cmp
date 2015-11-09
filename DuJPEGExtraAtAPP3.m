//
//  DuJPEGExtraAtAPP3.m
//  cmp
//
//  Created by hejunqiu on 15/11/9.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import "DuJPEGExtraAtAPP3.h"
#import <objc/runtime.h>

NSString *const kDuCompressExtraHeadString = @"Compressed by Baidu in China";
const int kHeadStringLength = 28;
const int kCompressVersion = 300;
const int kCompressAPPn = 3;
const int kReserve = 0x7F;
const NSUInteger kDuCompressExtraFlag = ((kHeadStringLength << 24) | (kCompressVersion << 16) | (kCompressAPPn << 8) | kReserve);

@implementation DuJPEGExtraAtAPP3

- (instancetype)init
{
    self = [super init];
    if (self) {
        _headString = kDuCompressExtraHeadString;
        _version = kCompressVersion;
        _compressDateTime = [NSDate date].description;
        _APPn = 3;
        _flag = kDuCompressExtraFlag;
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)JSON
{
    self = [super init];
    if (self) {
        [self convert:JSON];
    }
    return self;
}

- (instancetype)initWithJSONString:(NSString *)JSON
{
    NSError *err = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:0
                                                           error:&err];
    if (err) {
        return nil;
    }
    return [self initWithJSON:dict];

}

- (void)convert:(NSDictionary *)dataSource
{
    NSArray *keys = [self propertyKeys];
    id propertyValue;
    for (NSString *key in [dataSource allKeys]) {
        if ([keys containsObject:key]) {
            propertyValue = [dataSource valueForKey:key];
            if (propertyValue && ![propertyValue isKindOfClass:[NSNull class]]) {
                [self setValue:propertyValue forKey:key];
            }
        }
    }
}

- (NSArray *)propertyKeys
{
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    NSMutableArray *propertys = [NSMutableArray arrayWithCapacity:outCount];
    for (i = 0; i<outCount; ++i)
    {
        objc_property_t property = properties[i];
        const char* char_f =property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:char_f];
        [propertys addObject:propertyName];
    }
    free(properties);
    return propertys;

}

- (NSDictionary *)JSONFromSelf
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *keys = [self propertyKeys];
    id value = nil;
    for (NSString *key in keys) {
        value = [self valueForKey:key];
        [dict setValue:value forKey:key];
    }
    return dict;
}

- (NSString *)stringForJSON
{
    NSDictionary *dict = [self JSONFromSelf];
    NSData *json;
    @try {
        json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"%@\n", exception);
    }
    NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSString *)description
{
    return [self stringForJSON];
}
@end
