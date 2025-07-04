//
//  FFmpegParseHandler.h
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "PacketQueue.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct MySampleBuffer {
    CMSampleBufferRef sampleBuffer;
    int serial;
    BOOL isLastPacket;
    BOOL isFirstFrame;
    int64_t startTime;
    int flags;
}MySampleBuffer;


typedef enum : NSUInteger {
    RTMP,
    LocalFile
} fileType;

typedef enum : NSUInteger {
    H264EncodeFormat,
    H265EncodeFormat,
} VideoEncodeFormat;

typedef struct VideoState {
    BOOL isSeekReq;
    BOOL isReadPacketEnd;
    BOOL quit;
    BOOL parseEnd;
    BOOL audioRendererIsReadyForMoreData;
    Float64 seekTimeStamp;
}VideoState;

struct ParseVideoDataInfo {
    int                     flags;
    int                     serial;
    BOOL                    isLastPacket;
    BOOL                    seekRequest;
    BOOL                    isNeedResetTimebase;
    uint8_t                 *data;
    int                     dataSize;
    uint8_t                 *extraData;
    int                     extraDataSize;
    Float64                 pts;
    Float64                 time_base;
    int                     videoRotate;
    int                     fps;
    int                     width;
    int                     height;
    CMSampleTimingInfo      timingInfo;
    VideoEncodeFormat    videoFormat;
};

@interface FFmpegParseHandler : NSObject 
@property (nonatomic, assign) BOOL isPause;
@property (nonatomic, assign) BOOL isSeekReq;
@property (nonatomic, assign) Float64 seekTimeStamp;


/**
 Init Parse Handler by file path

 @param path file path
 @return the object instance
 */
- (instancetype)initWithPath:(NSString *)path videoState:(VideoState *)videoState;


/**
 Start parse file content

 Note:
 1.You could get the audio / video infomation by `XDXParseVideoDataInfo` ,  `XDXParseAudioDataInfo`.
 2.You could get the audio / video infomation by `AVPacket`.
 @param handler get some parse information.
 */
- (void)startParseWithCompletionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, struct ParseVideoDataInfo *videoInfo, struct MyPacket packet))handler;

- (void)startParseGetAVPackeWithCompletionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handler;

- (void)upDateAvContextFormatFromSeekTimeStamp:(Float64)timeStamp;

- (void)stopParse;
/**
 Get Method
 */
- (AVFormatContext *)getFormatContext;
- (AVBitStreamFilterContext *)getBitStreamFilter;
- (int)getVideoStreamIndex;
- (int)getAudioStreamIndex;

- (struct ParseVideoDataInfo)parseVideoPacket: (AVPacket)packet;
- (void)readFile:(PacketQueue *)videoPacketQueue audioPacketQueue:(PacketQueue *)audioPacketQueue videoState:(VideoState *)videoState;
- (void)destroyParseHandler;
@end

NS_ASSUME_NONNULL_END
