//
//  ViewController.m
//  cmp
//
//  Created by baidu on 15/11/5.
//  Copyright © 2015年 baidu. All rights reserved.
//

#import "ViewController.h"
#import "DuJPEGLibObject.h"

#define kInitialCompressQuality 0.20

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *origin;
@property (weak, nonatomic) IBOutlet UIImageView *compress;
@property (nonatomic, strong) DuJPEGLibObject *jpegLibObject;

@end

@implementation ViewController
- (IBAction)cleanMemoryAndRestartMemory:(id)sender
{
    _jpegLibObject = nil;
    _compress.image = nil;
    _origin.image = nil;
}

- (IBAction)onGoButtonClicked:(id)sender
{
    if (!_origin.image) {
//        _origin.image = [UIImage imageNamed:@"hhh"];
    }
    BOOL useAppleAPI = NO;
    if (useAppleAPI) {
        [self AppleAPIDo];
    } else {
        [self UseLibJPEG];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _jpegLibObject = [DuJPEGLibObject JPEGLibObject];

    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)UseLibJPEG
{
    if (_jpegLibObject == nil) {
        _jpegLibObject = [DuJPEGLibObject JPEGLibObject];
    }
    _jpegLibObject.imageFilePath = @"/Users/baidu/Documents/Xcode Projects/cmp/hhh.jpg";
    int errCode = 0;
//    BOOL need = [_jpegLibObject pretreatment:&errCode];
    if (errCode == 0 /* && need */) {
        _jpegLibObject.quality = 20;
        [_jpegLibObject pretreatment];
        [_jpegLibObject compress];
        NSData *data = [_jpegLibObject imageData];
        NSLog(@"%lu\n", (unsigned long)_jpegLibObject.lengthCompressed);
        [self save:data];
//        _compress.image = [_jpegLibObject imageCompressed];
    }
    NSLog(@"extra info:%@\n", _jpegLibObject.extraCompressInfo);
}

- (void)AppleAPIDo
{
    NSData *data = [self compressImage:[UIImage imageNamed:@"hh"] qualityLimit:kInitialCompressQuality];
//    _compress.image = [UIImage imageWithData:data];
    [self save:data];
}

- (NSData *)compressImage:(UIImage *)origin qualityLimit:(CGFloat)quality
{
    CGFloat totalSize = UIImageJPEGRepresentation(origin, 1).length / 1000.0;
    NSData *imageData = UIImageJPEGRepresentation(origin, quality);
    NSLog(@"origin size:%.3f KB, compress size:%.3f KB\n", totalSize, imageData.length / 1000.0);
    return imageData;
}

- (NSData *)compressImage:(UIImage *)originImage originSizeKB:(CGFloat)originSize
{
    CGFloat quality = kInitialCompressQuality;
    NSData *compressedImageData = UIImageJPEGRepresentation(originImage, quality);
    CGFloat compressedImageSize = compressedImageData.length / 1000.0;
    while (compressedImageSize > originSize && quality > 0.01) {
        quality -= 0.1;
        compressedImageData = UIImageJPEGRepresentation(originImage, quality);
        compressedImageSize = compressedImageData.length / 1000.0;
    }

    return nil;
}

- (void)save:(NSData *)data
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *date = [[NSDate date] description];
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", date]];   // 保存文件的名称
    BOOL result = [data writeToFile:filePath atomically:NO]; // 保存成功会返回YES
    NSLog(@"save at:%@\n", filePath);
    NSLog(@"save state:%@\n",@(result));
}
@end
