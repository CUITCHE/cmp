//
//  DuJPEGExtraAtAPPn.m
//  mobileguard
//
//  Created by hejunqiu on 15/11/9.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import "DuJPEGExtraAtAPPn.h"
#import <objc/runtime.h>

NSString *const kDuCompressExtraHeadString = @"Compressed by Baidu in China";
const int kJPEG_APP0 = 0xE0;
const int kJPEG_APP0Default = 0xE0E0E0E0;

const int kHeadStringLength = 28;

const int kCompressVersion = 300;
const int kCompressVersionDefault = -0xFF09;

const int kCompressAPPn = kJPEG_APP0 + 3;
const int kReserve = 0x7F;

const NSUInteger kDuCompressExtraFlag = ((kHeadStringLength << 24) | (kCompressVersion << 16) | (kCompressAPPn << 8) | kReserve);
const NSUInteger kDuCImpressExtraFlagDefault = ~0;

@implementation DuJPEGExtraAtAPPn

- (instancetype)init
{
    self = [super init];
    if (self) {
        _headString = kDuCompressExtraHeadString;
        _version = kCompressVersion;
        _compressDateTime = [NSDate date].description;
        _APPn = kCompressAPPn;
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

    self = [super init];
    if (self) {
        [self parse:JSON];
    }
    return self;

}

- (void)convert:(NSDictionary *)dataSource
{
    // set values to Default
    _flag = kDuCImpressExtraFlagDefault;
    _version = kCompressVersionDefault;
    _APPn = kJPEG_APP0Default;

    NSArray *keys = [self propertyKeys];
    id propertyValue;
    NSArray *keysForDataSource = [dataSource allKeys];
    for (NSString *key in keysForDataSource) {
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
    NSArray *keys = [self propertyKeys];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:keys.count];
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

- (void)parse:(NSString *)JSON
{
    NSError *err = nil;
    NSDictionary *dict = nil;
    @try {
        [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding]
                                        options:0
                                          error:&err];
    }
    @catch (NSException *exception) {
        NSLog(@"%@\n",exception);
    }
    if (!dict) {
        return;
    }
    [self convert:dict];
}

- (BOOL)isValid
{
    BOOL ret = ((_APPn != 0) && (_APPn != 0x0F) && (_APPn != 0x08) && (_APPn >= kJPEG_APP0 && _APPn <= kJPEG_APP0 + 0x0F) && (_version == kCompressVersion) && (_flag == kDuCompressExtraFlag));
    return ret;
}

- (NSString *)description
{
    return [self stringForJSON];
}

@end
