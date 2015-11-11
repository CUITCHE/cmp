//
//  DuJPEGLibObject.mm
//  mobileguard
//
//  Created by hejunqiu on 15/11/7.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import "DuJPEGLibObject.h"
#include "jpeglib.h"
#include "jpegint.h"
#include <setjmp.h>
#include <stdio.h>
#include <vector>
#import <UIKit/UIImage.h>
using namespace std;

#define release_pointer(p) if(p) delete p, p = NULL
#define MEMORY_1M (1024 * 1024)
#define MEMORY_4M (4 * MEMORY_1M)
#define MEMORY_10M (10 * MEMORY_1M)

typedef NS_ENUM(NSUInteger, DuJPEGCompressStep) {
    DuJPEGCompressStepReady,
    DuJPEGCompressStepPretreatment,
    DuJPEGCompressStepDecompress,
    DuJPEGCompressStepEstimate,
    DuJPEGCompressStepCompressing,
    DuJPEGCompressStepCompressed
};

#pragma mark - C style
typedef struct my_error_mgr
{
    struct jpeg_error_mgr pub;	/* "public" fields */

    jmp_buf setjmp_buffer;      /* for return to caller */
}my_error_mgr;

typedef struct my_error_mgr * my_error_ptr;
typedef struct jpeg_decompress_struct jpeg_decompress_struct;
typedef struct jpeg_compress_struct jpeg_compress_struct;

METHODDEF(void) my_error_exit (j_common_ptr cinfo);
METHODDEF(void) j_progress_callback_method(j_common_ptr cinfo);

#pragma mark - DuJPEGCompress
@interface DuJPEGLibObject ()
{
    jpeg_decompress_struct *decompressinfo;
    vector<JSAMPLE> *in_image_data;
    FILE *infile;

    jpeg_compress_struct *compressinfo;
    vector<JSAMPLE> *out_image_data;

    // common fields
    my_error_mgr *jerr;
    NSTimeInterval invokeTimerval;
    struct jpeg_progress_mgr *progress_mgr;
}

@property (nonatomic, assign) DuJPEGCompressStep compressStep;
/// return NSData and copy all of image-compressed bytes.
@property (nonatomic, strong) NSData *imageData;
/// Create UIImage from image-compressed bytes.
@property (nonatomic, strong) UIImage *imageCompressed;
@property (nonatomic, strong) DuJPEGExtraAtAPPn *extraCompressInfo;
@property (nonatomic, assign) NSUInteger lengthOrigin;

@end


@implementation DuJPEGLibObject

- (instancetype)init;
{
    self = [super init];
    if (self) {
        _compressStep = DuJPEGCompressStepReady;
        jerr = new my_error_mgr;
        _tolerate = NO;
        _quality = 50;
        progress_mgr = new struct jpeg_progress_mgr;
        progress_mgr->progress_monitor = j_progress_callback_method;
    }
    return self;
}

+ (instancetype)JPEGLibObject
{
    return [[DuJPEGLibObject alloc] init];
}

- (void)dealloc
{
    [self releaseMemory];
}

- (void)releaseMemory
{
    if (decompressinfo) {
        jpeg_destroy_decompress(decompressinfo);
        decompressinfo->client_data = NULL;
        release_pointer(decompressinfo);
        release_pointer(in_image_data);
    }

    if (compressinfo) {
        jpeg_destroy_compress(compressinfo);
        compressinfo->client_data = NULL;
        release_pointer(compressinfo);
        release_pointer(out_image_data);
    }

    release_pointer(jerr);
    // progress
    release_pointer(progress_mgr);
    _imageCompressed = nil;
    _imageData = nil;
}

- (BOOL)decompressInitial
{
    _imageCompressed = nil;
    _imageData = nil;

    // initial
    if (!decompressinfo) {
        decompressinfo = new jpeg_decompress_struct;
        decompressinfo->client_data = (__bridge void *)self;
    }
    if (!in_image_data) {
        in_image_data = new vector<JSAMPLE>();
    }
    in_image_data->clear();

    // We set up the normal JPEG error routines, then override error_exit.
    decompressinfo->err = jpeg_std_error(&jerr->pub);
    jerr->pub.error_exit = my_error_exit;

    // source file
    infile = NULL;
    if (_imageFilePath) {
        infile = fopen(_imageFilePath.UTF8String, "rb");
        if (infile == NULL) {
            if ([_delegate respondsToSelector:@selector(compress:error:)]) {
                [_delegate compress:self error:DuJPEGCompressErrorTypeFileNotExists];
            }
            return NO;
        }
        // get length of file
        fseek(infile, 0, SEEK_END);
        _lengthOrigin = ftell(infile);
        fseek(infile, 0, SEEK_SET);
    }
    // Step 1: allocate and initialize JPEG decompression object

    // Establish the setjmp return context for my_error_exit to use.
    if (setjmp(jerr->setjmp_buffer)) {
        jpeg_abort_decompress(decompressinfo);
        if (infile) {
            fclose(infile);
            infile = NULL;
        }
        if ([_delegate respondsToSelector:@selector(compress:error:)]) {
            [_delegate compress:self error:DuJPEGLibObjectErrorTypeJumpLogFailed];
        }
        return NO;
    }
    // Now we can initialize the JPEG decompression object.
    jpeg_create_decompress(decompressinfo);

    // Step 2: specify data source (eg, a file)
    if (infile) {
        jpeg_stdio_src(decompressinfo, infile);
    } else {
        if (!_compressSource) {
            if ([_delegate respondsToSelector:@selector(compress:error:)]) {
                [_delegate compress:self error:DuJPEGLibObjectErrorTypeNoImageSource];
            }
            return NO;
        }
        _lengthOrigin = _compressSourceLength;
        jpeg_mem_src(decompressinfo, _compressSource, _compressSourceLength);
    }

    return YES;
}

- (BOOL)pretreatment:(int *)errCode
{
    if (!errCode) {
        return NO;
    }
    *errCode = 0;
    if (_compressStep >= DuJPEGCompressStepPretreatment) {
        return NO;
    }

    if (![self decompressInitial]) {
        *errCode = ~0;
        return NO;
    }
    _compressStep = DuJPEGCompressStepPretreatment;

    // read markers
    jpeg_save_markers(decompressinfo, JPEG_COM, 0XFFFF);
    for (int i=0; i<16; ++i) {
        jpeg_save_markers(decompressinfo, JPEG_APP0 + i, 0xFFFF);
    }
    // Step 3: read file parameters with jpeg_read_header()
    (void) jpeg_read_header(decompressinfo, TRUE);
    jpeg_saved_marker_ptr head = decompressinfo->marker_list;
    while (head) {
        if (head->marker == kCompressAPPn) {
            NSString *dataSource = [[NSString alloc] initWithBytes:head->data length:head->data_length encoding:NSUTF8StringEncoding];
            if (!_extraCompressInfo) {
                _extraCompressInfo = [[DuJPEGExtraAtAPPn alloc] initWithJSONString:dataSource];
            } else {
                [_extraCompressInfo parse:dataSource];
            }
            break;
        }
        head = head->next;
    }
    return (_extraCompressInfo && [_extraCompressInfo isValid]);
}

- (BOOL)decompress
{
    // 尝试执行预处理流程
    int errCode = 0;
    [self pretreatment:&errCode];
    if (errCode != 0) {
        jpeg_abort_decompress(decompressinfo);
        return NO;
    }
    
    // 解压缩流程已经走过
    if (_compressStep >= DuJPEGCompressStepDecompress) {
        return YES;
    }
    _compressStep = DuJPEGCompressStepDecompress;

    (void) jpeg_start_decompress(decompressinfo);

    // JSAMPLEs per row in output buffer
    const int row_stride = decompressinfo->output_width * decompressinfo->output_components;
    // Make a one-row-high sample array that will go away when done with image
    JSAMPARRAY _buffer_ = (*decompressinfo->mem->alloc_sarray)((j_common_ptr) decompressinfo, JPOOL_IMAGE, row_stride, 1);
    JSAMPROW buffer = _buffer_[0];
    JSAMPROW buffer_end = buffer + row_stride;
    while (decompressinfo->output_scanline < decompressinfo->output_height) {
        jpeg_read_scanlines(decompressinfo, &buffer, 1);
        in_image_data->insert(in_image_data->end(), buffer, buffer_end);
    }

    if (infile) {
        fclose(infile);
        infile = NULL;
    }

    return YES;
}

- (void)compressInitial
{
    // initial
    if (!compressinfo) {
        compressinfo = new jpeg_compress_struct;
        compressinfo->client_data = (__bridge void *)self;
    }

    if (!out_image_data) {
        out_image_data = new vector<JSAMPLE>();
    }
    out_image_data->clear();
    vector<JSAMPLE>::size_type memory = in_image_data->size() * (_quality / 100.0);
    if (memory > MEMORY_10M) {
        memory = MEMORY_10M;
    }
    out_image_data->resize(memory);
    compressinfo->err = jpeg_std_error(&jerr->pub);

    jpeg_create_compress(compressinfo);

    // 这里我们将destination源设置到vector中去
    unsigned long outsize = out_image_data->size();
    JSAMPLE *buffer_pointer = &(*out_image_data)[0];
    jpeg_mem_dest(compressinfo, &buffer_pointer, &outsize);

    // image width and height, in pixels
    compressinfo->image_width = decompressinfo->image_width;
    compressinfo->image_height = decompressinfo->image_height;
    // # of color components per pixel
    compressinfo->input_components = decompressinfo->num_components;
    // colorspace of input image
    compressinfo->in_color_space = JCS_RGB;

    jpeg_set_defaults(compressinfo);
    // improve compress quality and needs more time. But can be ignored.
    compressinfo->optimize_coding = TRUE;

    jpeg_set_quality(compressinfo, _quality, TRUE /* limit to baseline-JPEG values */);
    compressinfo->progress = NULL;
}

- (void)compress
{
    // Firstly decompress JPEG
    if (![self decompress]) {
        return;
    }

    if ([_delegate respondsToSelector:@selector(willCompress:)]) {
        [_delegate willCompress:self];
    }
    [self compressInitial];

    // set progress method
    compressinfo->progress = progress_mgr;
    jpeg_start_compress(compressinfo, TRUE);

    // wirte extra info
    [self writeExtraInfoIntoCompressor];

    // JSAMPLEs per row in image_buffer
    const int row_stride = compressinfo->image_width * compressinfo->input_components;
    // pointer to JSAMPLE row[s]
    JSAMPROW row_pointer;
    JSAMPLE *image_buffer = &(*in_image_data)[0];
    while (compressinfo->next_scanline < compressinfo->image_height) {
        row_pointer = &image_buffer[compressinfo->next_scanline * row_stride];
        (void) jpeg_write_scanlines(compressinfo, &row_pointer, 1);
    }

    jpeg_finish_compress(compressinfo);
    [self JPEGLibObject:NO progress:100];

    // 这里不释放所有资源，在dealloc中统一释放，便于下次再利用
    jpeg_abort_compress(compressinfo);

    if ([_delegate respondsToSelector:@selector(didCompress:)]) {
        [_delegate didCompress:self];
    }
    [self resetCompressState];
}

- (void)resetCompressState
{
    (void) jpeg_finish_decompress(decompressinfo);

    // 这里，我们需要保留内存，以备下次使用的时候不用再分配，故而这里调用
    // jpeg_abort_decompress();
    jpeg_abort_decompress(decompressinfo);
    _compressStep = DuJPEGCompressStepReady;
}

- (void)memoryWarnings
{
    [self releaseMemory];
}

#pragma mark - hepler
- (void)writeExtraInfoIntoCompressor
{
    _extraCompressInfo = [[DuJPEGExtraAtAPPn alloc] init];
    NSString *stringStream = [_extraCompressInfo stringForJSON];
    jpeg_write_marker(compressinfo, _extraCompressInfo.APPn, (const JOCTET *)(stringStream.UTF8String), (unsigned int)stringStream.length);
    jpeg_saved_marker_ptr head = decompressinfo->marker_list;
    while (head) {
        if (head->marker != _extraCompressInfo.APPn) {
            jpeg_write_marker(compressinfo, head->marker, head->data, head->data_length);
        }
        head = head->next;
    }
}

#pragma mark - proerties
- (void)setQuality:(int)quality
{
    if (quality <= 100 && quality >= 0) {
        _quality = quality;
    }
}

- (NSUInteger)lengthCompressed
{
    return out_image_data->size() - static_cast<vector<JSAMPLE>::size_type>(compressinfo->dest->free_in_buffer);
}

- (const Byte *)bufferCompressed
{
    return out_image_data->data();
}

- (CGSize)imageSize
{
    CGSize imageSize = CGSizeMake(static_cast<CGFloat>(decompressinfo->image_width), static_cast<CGFloat>(decompressinfo->image_height));
    return imageSize;
}

- (NSData *)imageData
{
    if (_imageData) {
        return _imageData;
    }
    _imageData = [NSData dataWithBytes:out_image_data->data() length:self.lengthCompressed];
    return _imageData;
}

- (UIImage *)imageCompressed
{
    if (_imageCompressed) {
        return _imageCompressed;
    }
    _imageCompressed = [UIImage imageWithData:self.imageData];
    return _imageCompressed;
}

#pragma mark - invoke delegate's method
- (void)JPEGLibObject:(BOOL)isCallback progress:(NSUInteger)progress
{
    if (isCallback && [[NSProcessInfo processInfo] systemUptime] - invokeTimerval < 0.001) {
        return;
    }
    if ([_delegate respondsToSelector:@selector(compress:progress:)]) {
        [_delegate compress:self progress:progress];
    }
    NSLog(@"compressor complete:%lu%%...", (unsigned long)progress);
    invokeTimerval = [[NSProcessInfo processInfo] systemUptime];
}

@end

#pragma mark - C style
/*
 * Here's the routine that will replace the standard error_exit method:
 */
METHODDEF(void) my_error_exit(j_common_ptr cinfo)
{
    /* cinfo->err really points to a my_error_mgr struct, so coerce pointer */
    my_error_ptr myerr = (my_error_ptr) cinfo->err;

    /* Always display the message. */
    /* We could postpone this until after returning, if we chose. */
    (*cinfo->err->output_message) (cinfo);

    /* Return control to the setjmp point */
    longjmp(myerr->setjmp_buffer, 1);
}

/**
 * C-style call back method. Here will invoke
 * function of OC-object style.
 *
 * @param cinfo jpeg_decompress_struct or jpeg_compress_struct is ok.
 */
METHODDEF(void) j_progress_callback_method(j_common_ptr cinfo)
{
    struct jpeg_progress_mgr *progress = cinfo->progress;
    CGFloat complete_percent = (progress->completed_passes + (progress->pass_counter / (progress->pass_limit * 1.0))) / progress->total_passes;
    DuJPEGLibObject *jpeglib_object = (__bridge DuJPEGLibObject *)cinfo->client_data;
    [jpeglib_object JPEGLibObject:YES progress:(NSUInteger)(complete_percent * 100)];
}