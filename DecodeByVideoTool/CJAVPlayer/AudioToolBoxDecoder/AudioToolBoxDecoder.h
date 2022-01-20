//
//  AudioToolBoxDecoder.h
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/4.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AVFoundation/AVFoundation.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioToolBoxDecoder : NSObject
{
    @public
    AudioConverterRef           mAudioConverter;
    AudioStreamBasicDescription mDestinationFormat;
    AudioStreamBasicDescription mSourceFormat;
}

/**
 Init Audio Encoder
 @param sourceFormat source audio data format
 @param destFormatID destination audio data format
 @param isUseHardwareDecode Use hardware / software encode
 @return object.
 */
- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription)sourceFormat
                        destFormatID:(AudioFormatID)destFormatID
                          sampleRate:(float)sampleRate
                 isUseHardwareDecode:(BOOL)isUseHardwareDecode;

/**
 Encode Audio Data
 @param sourceBuffer source audio data
 @param sourceBufferSize source audio data size
 @param completeHandler get audio data after encoding
 */
- (void)decodeAudioWithSourceBuffer:(void *)sourceBuffer
                   sourceBufferSize:(UInt32)sourceBufferSize
                    completeHandler:(void(^)(AudioBufferList *destBufferList, UInt32 outputPackets, AudioStreamBasicDescription *outputBasicDescriptions))completeHandler;


- (void)freeDecoder;

@end

NS_ASSUME_NONNULL_END
