//
//  DuJPEGLibObject.mm
//  cmp
//
//  Created by hejunqiu on 15/11/7.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import "DuJPEGLibObject.h"
#include "jpeglib.h"
#include <setjmp.h>
#include <stdio.h>
#include <vector>
#import <UIKit/UIImage.h>
using namespace std;

#define release_pointer(p) if(p) delete p, p = NULL
#define MEMORY_1M (1024 * 1024)
#define MEMORY_4M (4 * MEMORY_1M)
#define MEMORY_10M (10 * MEMORY_1M)

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
    /* This struct contains the JPEG decompression parameters and pointers to
     * working space (which is allocated as needed by the JPEG library).
     */
    jpeg_decompress_struct *decompressinfo;
    vector<JSAMPLE> *in_image_data;
    FILE *infile;

    /* This struct contains the JPEG compression parameters and pointers to
     * working space (which is allocated as needed by the JPEG library).
     * It is possible to have several such structures, representing multiple
     * compression/decompression processes, in existence at once.  We refer
     * to any one struct (and its associated working data) as a "JPEG object".
     */
    jpeg_compress_struct *compressinfo;
    vector<JSAMPLE> *out_image_data;

    /* We use our private extension JPEG error handler.
     * Note that this struct must live as long as the main JPEG parameter
     * struct, to avoid dangling-pointer problems.
     */
    // common fields
    my_error_mgr *jerr;
    NSTimeInterval invokeTimerval;
    struct jpeg_progress_mgr *progress_mgr;
}
/// return NSData and copy all of image-compressed bytes.
@property (nonatomic, strong) NSData *imageData;
/// Create UIImage from image-compressed bytes.
@property (nonatomic, strong) UIImage *imageCompressed;

@end


@implementation DuJPEGLibObject

- (instancetype)init;
{
    self = [super init];
    if (self) {
        jerr = new my_error_mgr;
        _tolerate = NO;
        _quality = 65;
        progress_mgr = new struct jpeg_progress_mgr;
        progress_mgr->progress_monitor = j_progress_callback_method;
    }
    return self;
}

+ (instancetype)jpegLibObject
{
    return [[DuJPEGLibObject alloc] init];
}

- (void)dealloc
{
    [self releaseMemory];
}

- (void)releaseMemory
{
    jpeg_destroy_decompress(decompressinfo);
    decompressinfo->client_data = NULL;
    release_pointer(decompressinfo);
    release_pointer(in_image_data);

    jpeg_destroy_compress(compressinfo);
    compressinfo->client_data = NULL;
    release_pointer(compressinfo);
    release_pointer(out_image_data);
    release_pointer(jerr);
    // progress
    release_pointer(progress_mgr);
}

- (BOOL)decompressInitial
{
    // initial
    if (!decompressinfo) {
        decompressinfo = new jpeg_decompress_struct;
        decompressinfo->client_data = (__bridge void *)self;
    }
    if (!in_image_data) {
        in_image_data = new vector<JSAMPLE>();
    }
    in_image_data->clear();

    /* We set up the normal JPEG error routines, then override error_exit. */
    decompressinfo->err = jpeg_std_error(&jerr->pub);
    jerr->pub.error_exit = my_error_exit;

    /* source file */
    infile = NULL;
    if (_imageFilePath) {
        infile = fopen(_imageFilePath.UTF8String, "rb");
        if (infile == NULL) {
            if ([_delegate respondsToSelector:@selector(compress:error:)]) {
                [_delegate compress:self error:DuJPEGCompressErrorTypeFileNotExists];
            }
            return NO;
        }
    }
    /* Step 1: allocate and initialize JPEG decompression object */

    /* Establish the setjmp return context for my_error_exit to use. */
    if (setjmp(jerr->setjmp_buffer)) {
        /* If we get here, the JPEG code has signaled an error.
         * We need to clean up the JPEG object, close the input file, and return.
         */
        jpeg_abort_decompress(decompressinfo);
        fclose(infile);
        infile = NULL;
        if ([_delegate respondsToSelector:@selector(compress:error:)]) {
            [_delegate compress:self error:DuJPEGLibObjectErrorTypeJumpLogFailed];
        }
        return NO;
    }
    /* Now we can initialize the JPEG decompression object. */
    jpeg_create_decompress(decompressinfo);

    /* Step 2: specify data source (eg, a file) */
    if (infile) {
        jpeg_stdio_src(decompressinfo, infile);
    } else {
        if (!_compressSource) {
            if ([_delegate respondsToSelector:@selector(compress:error:)]) {
                [_delegate compress:self error:DuJPEGLibObjectErrorTypeNoImageSource];
            }
            return NO;
        }
        jpeg_mem_src(decompressinfo, _compressSource, _compressSourceLength);
    }

    /* Step 3: read file parameters with jpeg_read_header() */
    (void) jpeg_read_header(decompressinfo, TRUE);
    /* We can ignore the return value from jpeg_read_header since
     *   (a) suspension is not possible with the stdio data source, and
     *   (b) we passed TRUE to reject a tables-only JPEG file as an error.
     * See libjpeg.txt for more info.
     */

    /* Step 4: set parameters for decompression */

    /* set progress method */
    decompressinfo->progress = progress_mgr;

    /* In this example, we don't need to change any of the defaults set by
     * jpeg_read_header(), so we do nothing here.
     */

    /* Step 5: Start decompressor */
    if ([_delegate respondsToSelector:@selector(willCompress:)]) {
        [_delegate willCompress:self];
    }
    (void) jpeg_start_decompress(decompressinfo);
    /* We can ignore the return value since suspension is not possible
     * with the stdio data source.
     */
    progress_mgr->total_passes = 2;
    return YES;
}

- (void)decompress
{
    _imageCompressed = nil;
    _imageData = nil;
    
    [self decompressInitial];
    /* We may need to do some setup of our own at this point before reading
     * the data.  After jpeg_start_decompress() we have the correct scaled
     * output image dimensions available, as well as the output colormap
     * if we asked for color quantization.
     * In this example, we need to make an output work buffer of the right size.
     */
    /* JSAMPLEs per row in output buffer */
    const int row_stride = decompressinfo->output_width * decompressinfo->output_components;
    /* Make a one-row-high sample array that will go away when done with image */
    JSAMPARRAY _buffer_ = (*decompressinfo->mem->alloc_sarray)((j_common_ptr) decompressinfo, JPOOL_IMAGE, row_stride, 1);
    JSAMPROW buffer = _buffer_[0];
    /* Step 6: while (scan lines remain to be read) */
    /*           jpeg_read_scanlines(...); */

    /* Here we use the library's state variable cinfo.output_scanline as the
     * loop counter, so that we don't have to keep track ourselves.
     */
    while (decompressinfo->output_scanline < decompressinfo->output_height) {
        /* jpeg_read_scanlines expects an array of pointers to scanlines.
         * Here the array is only one element long, but you could ask for
         * more than one scanline at a time if that's more convenient.
         */
        jpeg_read_scanlines(decompressinfo, &buffer, 1);
        in_image_data->insert(in_image_data->end(), buffer, buffer + row_stride);
    }
    /* Step 7: Finish decompression */
    (void) jpeg_finish_decompress(decompressinfo);
    /* We can ignore the return value since suspension is not possible
     * with the stdio data source.
     */

    /* Step 8: Release JPEG decompression object */

    /* This is an important step since it will release a good deal of memory.
     * jpeg_destroy_decompress(decompressinfo);
     * 这里，我们需要保留内存，以备下次使用的时候不用再分配，故而这里调用
     * jpeg_abort_decompress();
     */
    jpeg_abort_decompress(decompressinfo);

    /* After finish_decompress, we can close the input file.
     * Here we postpone it until after no more JPEG errors are possible,
     * so as to simplify the setjmp error logic above.  (Actually, I don't
     * think that jpeg_destroy can do an error exit, but why assume anything...)
     */
    if (infile) {
        fclose(infile);
        infile = NULL;
    }

    /* At this point you may want to check to see whether any corrupt-data
     * warnings occurred (test whether jerr.pub.num_warnings is nonzero).
     */

    /* And we're done! */
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
}

- (void)compress
{
    // Firstly decompress JPEG
    [self decompress];


    /* Step 1: allocate and initialize JPEG compression object */

    /* We have to set up the error handler first, in case the initialization
     * step fails.  (Unlikely, but it could happen if you are out of memory.)
     * This routine fills in the contents of struct jerr, and returns jerr's
     * address which we place into the link field in cinfo.
     */
    [self compressInitial];

    /* Now we can initialize the JPEG compression object. */
    jpeg_create_compress(compressinfo);

    /* Step 2: specify data destination (eg, a file) */
    /* Note: steps 2 and 3 can be done in either order. */

    /* 这里我们将destination源设置到vector中去 */
    unsigned long outsize = out_image_data->size();
    JSAMPLE *buffer_pointer = &(*out_image_data)[0];
    jpeg_mem_dest(compressinfo, &buffer_pointer, &outsize);
    /* Step 3: set parameters for compression */

    /* First we supply a description of the input image.
     * Four fields of the cinfo struct must be filled in:
     */
    compressinfo->image_width = decompressinfo->image_width;            /* image width and height, in pixels */
    compressinfo->image_height = decompressinfo->image_height;
    compressinfo->input_components = decompressinfo->num_components;	/* # of color components per pixel */
    compressinfo->in_color_space = JCS_RGB;                             /* colorspace of input image */
    /* Now use the library's routine to set default compression parameters.
     * (You must set at least cinfo.in_color_space before calling this,
     * since the defaults depend on the source color space.)
     */
    jpeg_set_defaults(compressinfo);
    // improve compress quality, but time is more than before.
    compressinfo->optimize_coding = TRUE;
    /* set progress method */
    compressinfo->progress = progress_mgr;

    /* Now you can set any non-default parameters you wish to.
     * Here we just illustrate the use of quality (quantization table) scaling:
     */
    jpeg_set_quality(compressinfo, _quality, TRUE /* limit to baseline-JPEG values */);

    /* Step 4: Start compressor */

    /* TRUE ensures that we will write a complete interchange-JPEG file.
     * Pass TRUE unless you are very sure of what you're doing.
     */
    jpeg_start_compress(compressinfo, TRUE);
    progress_mgr->completed_passes = 1;
    progress_mgr->pass_counter = 0;

    /* Step 5: while (scan lines remain to be written) */
    /*           jpeg_write_scanlines(...); */

    /* Here we use the library's state variable cinfo.next_scanline as the
     * loop counter, so that we don't have to keep track ourselves.
     * To keep things simple, we pass one scanline per call; you can pass
     * more if you wish, though.
     */
    const int row_stride = compressinfo->image_width * compressinfo->input_components;	/* JSAMPLEs per row in image_buffer */
    JSAMPROW row_pointer;	/* pointer to JSAMPLE row[s] */
    JSAMPLE *image_buffer = &(*in_image_data)[0];
    while (compressinfo->next_scanline < compressinfo->image_height) {
        /* jpeg_write_scanlines expects an array of pointers to scanlines.
         * Here the array is only one element long, but you could pass
         * more than one scanline at a time if that's more convenient.
         */
        row_pointer = &image_buffer[compressinfo->next_scanline * row_stride];
        (void) jpeg_write_scanlines(compressinfo, &row_pointer, 1);
    }
    /* Step 6: Finish compression */
    jpeg_finish_compress(compressinfo);
    [self JPEGLibObject:NO progress:100];

    /* Step 7: release JPEG compression object */

    /* This is an important step since it will release a good deal of memory.
     * 这里不释放所有资源，在dealloc中统一释放，便于下次再利用
     */
    jpeg_abort_compress(compressinfo);

    /* And we're done! */
    if ([_delegate respondsToSelector:@selector(didCompress:)]) {
        [_delegate didCompress:self];
    }
}

- (void)memoryWarnings
{
    [self releaseMemory];
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
    return CGSize {.width =static_cast<CGFloat>(decompressinfo->image_width), .height = static_cast<CGFloat>(decompressinfo->image_height)};
}

- (NSData *)imageData
{
    if (_imageData) {
        return _imageData;
    }
    NSData *data = [NSData dataWithBytes:out_image_data->data() length:self.lengthCompressed];
    _imageData = data;
    return data;
}

- (UIImage *)imageCompressed
{
    if (_imageCompressed) {
        return _imageCompressed;
    }
    UIImage *image = [UIImage imageWithData:self.imageData];
    _imageCompressed = image;
    return image;
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
    NSLog(@"compressor complete:%lu%%...\n", (unsigned long)progress);
    invokeTimerval = [[NSProcessInfo processInfo] systemUptime];
}

@end

#pragma mark - C style
/*
 * Here's the routine that will replace the standard error_exit method:
 */
METHODDEF(void) my_error_exit (j_common_ptr cinfo)
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
 * C-style call back method. There will invoke
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