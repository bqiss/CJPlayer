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
static const NSNotificationName  kDecodeIsFinishNotificationKey = @"CJDeocderManangerDecodeIsFinish";


@protocol CJDecoderManagerCallDelegate <NSObject>
- (void)CJDecoderGetVideoSampleBufferCallback:(MySampleBuffer *)sampleBuffer;

- (void)CJDecoderGetAudioSampleBufferCallback:(MySampleBuffer *)sampleBuffer isFirstFrame:(BOOL)isFirstFrame;
@end

@interface CJDecoderManager : NSObject
@property (nonatomic, weak) id<CJDecoderManagerCallDelegate> delegate;


/* videoProperty */
@property(nonatomic, assign) int64_t videoDuration;
- (AVFormatContext *)getFormatContext;

- (instancetype)initWithFilePath: (NSString *)path fileType:(fileType) fileType videoState:(VideoState *)videoState;

- (void)startAudioToolBoxDecoder;

/* Start decoding whether keyframe or not (only decode audio) */
- (void)startAudioDecoder;

/* Start decoding whether keyframe or not (decode video and audio) */
- (void)startDecode:(VideoState *)videoState;

/* Start decoding until next keyframe (decode video and audio) */
- (void)startDecodeUntilNextKeyframe;


- (void)seekToTime:(Float64) stampTime;

- (void)pauseDecoder;
- (void)startDecoder;

@end

NS_ASSUME_NONNULL_END
