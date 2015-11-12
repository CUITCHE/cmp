//
//  DuJPEGLibObject.h
//  mobileguard
//
//  Created by hejunqiu on 15/11/7.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import "DuJPEGExtraAtAPPn.h"

@class UIImage;

@protocol DuJPEGCompressDelegate;

typedef NS_ENUM(Byte, DuJPEGLibObjectErrorType) {
    DuJPEGLibObjectErrorTypeNone,
    DuJPEGLibObjectErrorTypeFileNotExists,
    DuJPEGLibObjectErrorTypeJumpLogFailed,
    DuJPEGLibObjectErrorTypeNoImageSource,
    DuJPEGLibObjectErrorTypeNoNeedCompress,
    DuJPEGLibObjectErrorTypeNeedsCompress,
    DuJPEGLibObjectErrorTypeDecompressInitialFailed
};

typedef NS_ENUM(NSUInteger, DuJPEGCompressStep) {
    DuJPEGCompressStepReady,
    DuJPEGCompressStepPretreatment,
    DuJPEGCompressStepDecompress,
    DuJPEGCompressStepCompressing,
    DuJPEGCompressStepCompressed
};

#pragma mark - DuJPEGLibObject
@interface DuJPEGLibObject : NSObject

/**
 * Input source may come from disk. So here is file path of image. Also comes
 * from memory. But imageFilePath has highest priority. Once imageFilePath or
 * compressSource changed, compress state(see DuJPEGCompressStep) will be reset.
 *
 * @see DuJPEGCompressStep.
 */
@property (nonatomic, copy) NSString *imageFilePath;
@property (nonatomic, assign) Byte *compressSource;
@property (nonatomic, assign) NSUInteger compressSourceLength;

/**
 * Quality of image wants to be compressed. Its range is integer[0,100],
 * and 0 is lowest, 100 is best quality. Default is 50.
 * Once quality has been changed, compress state(see DuJPEGCompressStep) will be reset.
 *
 * @see DuJPEGCompressStep.
 */
@property (nonatomic, assign) int quality;

@property (nonatomic, assign, readonly) NSUInteger lengthCompressed;
@property (nonatomic, assign, readonly) const Byte *bufferCompressed;

@property (nonatomic, assign, readonly) CGSize imageSize;
/// Represent compress state.
@property (nonatomic, assign, readonly) DuJPEGCompressStep compressStep;
/// Return NSData and copy all of image-compressed bytes.
@property (nonatomic, strong, readonly) NSData *imageData;
/// Create UIImage from image-compressed bytes.
@property (nonatomic, strong, readonly) UIImage *imageCompressed;

/// You can learn more about image from property extraCompressInfo.
@property (nonatomic, strong, readonly) DuJPEGExtraAtAPPn *extraCompressInfo;
/// length of origin image.
@property (nonatomic, assign, readonly) NSUInteger lengthOrigin;

/// If you want to control compress process, you can do it throught it.
@property (nonatomic, weak) id<DuJPEGCompressDelegate> delegate;

+ (instancetype)JPEGLibObject;

/**
 * Invoke it before start compress.
 * We need not to treat the image if image was treated by app.
 * So, this function just do that. 
 *
 * @return DuJPEGLibObjectErrorTypeNeedsCompress if image needs to be treated.
 *
 * @see DuJPEGLibObjectErrorType.
 */
- (DuJPEGLibObjectErrorType)pretreatment;

/**
 * Begin compressing image.
 *
 * You can set value of properties of imageFilePath, quality before use it.
 * Once begin, properties above do not effact compress process.
 */
- (void)compress;

/**
 * It will release c-style memory. It's safe.
 */
- (void)memoryWarnings;

@end

@protocol DuJPEGCompressDelegate <NSObject>
@optional
// common
- (void)willCompress:(DuJPEGLibObject *)compressObject;
- (void)didCompress:(DuJPEGLibObject *)compressObject;
// compress
- (void)compress:(DuJPEGLibObject *)compressObject error:(DuJPEGLibObjectErrorType)error;
- (void)compress:(DuJPEGLibObject *)compressObject progress:(NSUInteger)progress;
@end
