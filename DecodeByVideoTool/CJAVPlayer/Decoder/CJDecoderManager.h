//
//  CJDecoder.h
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/22.
//

#import <Foundation/Foundation.h>
#import "AVFoundation/AVFoundation.h"
#import "FFmpegParseHandler.h"
#import "CJAudioDecoder.h"
#import "VideoToolBoxDecoder.h"
#import "PacketQueue.h"

NS_ASSUME_NONNULL_BEGIN
@protocol CJDecoderManagerCallDelegate <NSObject>
- (void)CJDecoderGetVideoSampleBufferCallback:(MySampleBuffer *)sampleBuffer;

- (void)CJDecoderGetAudioSampleBufferCallback:(MySampleBuffer *)sampleBuffer isFirstFrame:(BOOL)isFirstFrame;
@end

@interface CJDecoderManager : NSObject
@property (nonatomic, weak) id<CJDecoderManagerCallDelegate> delegate;


/* videoProperty */
@property(nonatomic, assign) int64_t videoDuration;
- (AVFormatContext *)getFormatContext;

- (instancetype)initWithFilePath: (NSString *)path videoState:(VideoState *)videoState usingBlock:(void (^)(BOOL audioInitialSuccess,BOOL videointialSuccess,BOOL parseHandlerInitialSuccess))block;

/* Start decoding whether keyframe or not (decode video and audio) */
- (void)startDecode:(VideoState *)videoState videoPakcetQueue:(PacketQueue *)videoPacketQueue audioPacketQueue:(PacketQueue *)audioPacketQueue;

- (void)seekToTime:(Float64) stampTime;

- (void)startDecodeAudioDataWithAVPacket:(MyPacket)packet;
- (void)startDecodeVideo:(MyPacket)packet;
- (void)destroyDecoderManager;
@end

NS_ASSUME_NONNULL_END
