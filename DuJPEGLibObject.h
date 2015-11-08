//
//  DuJPEGLibObject.h
//  cmp
//
//  Created by hejunqiu on 15/11/7.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

@class UIImage;
@protocol DuJPEGComressDelegate;

typedef NS_ENUM(Byte, DuJPEGLibObjectErrorType) {
    DuJPEGCompressErrorTypeNone,
    DuJPEGCompressErrorTypeFileNotExists,
    DuJPEGLibObjectErrorTypeJumpLogFailed,
    DuJPEGLibObjectErrorTypeNoImageSource
};

#pragma mark - DuJPEGLibObject
@interface DuJPEGLibObject : NSObject

/// Input source may come from disk. So here is file path of image. Also comes from memory. But imageFilePath has highest priority.
@property (nonatomic, copy) NSString *imageFilePath;
@property (nonatomic, assign) Byte *compressSource;
@property (nonatomic, assign) NSUInteger compressSourceLength;

/// Quality of image wants to be compressed. Its range is integer[0,100], and 0 is lowest, 100 is best quality. Default is 65.
@property (nonatomic, assign) int quality;

/// Set YES if you don't care size. Default is NO that is image'size less than origin image after compressed.
@property (nonatomic, assign) BOOL tolerate;

@property (nonatomic, assign, readonly) NSUInteger lengthCompressed;
@property (nonatomic, assign, readonly) const Byte *bufferCompressed;

@property (nonatomic, assign, readonly) CGSize imageSize;
/// return NSData and copy all of image-compressed bytes.
@property (nonatomic, strong, readonly) NSData *imageData;
/// Create UIImage from image-compressed bytes.
@property (nonatomic, strong, readonly) UIImage *imageCompressed;

/// If you want to control compress process, you can control throught it.
@property (nonatomic, weak) id<DuJPEGComressDelegate> delegate;

+ (instancetype)jpegLibObject;

/**
 * Begin compressing image.
 *
 * You can set value of properties of imageFilePath, quality, tolerate before use it.
 * Once begin, properties above do not effact compress process.
 */
- (void)compress;

- (void)memoryWarnings;

@end


@protocol DuJPEGComressDelegate <NSObject>
@optional
// common
- (void)willCompress:(DuJPEGLibObject *)compressObject;
- (void)didCompress:(DuJPEGLibObject *)compressObject;
// compress
- (void)compress:(DuJPEGLibObject *)compressObject error:(DuJPEGLibObjectErrorType)error;
- (void)compress:(DuJPEGLibObject *)compressObject progress:(NSUInteger)progress;
@end