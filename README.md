# cmp
- 用Objective-C封装JPEGLIB库，目前暂时只提供压缩接口
- 工程里已经添加了通用类型的编译后的jpeglib.a完全适用于模拟器和真机，以及32位64位的Unix操作系统上
- JPEGLIB库采用的9a版本
- Xcode 7.0
- SDK iOS9.0 编译

# DuJPEGLibObject
- 用Objective-C封装JPEGLIB，目前支持设置来自文件和内存的图片数据。只需要调用compress就可以进行压缩。
- 如果你想了解压缩进度，可以查看DuJPEGComressDelegate协议

#LICENSE
The MIT LICENSE

#OTHER
压缩大图片会非常耗费内存，目前没有考虑压缩优化。

本人尝试过压缩一个10M的全景图片，结果耗费200M左右的内存，显然这是需要优化的。
